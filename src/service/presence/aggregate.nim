const
  RustPath* = "service/presence/aggregate.rs"
  RustCrate* = "service"

import std/tables

const
  PresenceBusy* = "org.matrix.msc3026.busy"
  PresenceOnline* = "online"
  PresenceUnavailable* = "unavailable"
  PresenceOffline* = "offline"

type
  DeviceKeyKind* = enum
    dkDevice
    dkRemote
    dkUnknownLocal

  DeviceKey* = object
    kind*: DeviceKeyKind
    deviceId*: string

  StatusMsgKind* = enum
    smSet
    smUnchanged

  StatusMsg* = object
    kind*: StatusMsgKind
    hasValue*: bool
    value*: string

  DevicePresence* = object
    state*: string
    currentlyActive*: bool
    lastActiveTs*: uint64
    lastUpdateTs*: uint64
    hasStatusMsg*: bool
    statusMsg*: string

  AggregatedPresence* = object
    state*: string
    currentlyActive*: bool
    lastActiveTs*: uint64
    hasStatusMsg*: bool
    statusMsg*: string
    deviceCount*: int

  PresenceAggregator* = object
    devices*: Table[string, Table[string, DevicePresence]]

proc initPresenceAggregator*(): PresenceAggregator =
  PresenceAggregator(devices: initTable[string, Table[string, DevicePresence]]())

proc deviceKey*(deviceId: string): DeviceKey =
  DeviceKey(kind: dkDevice, deviceId: deviceId)

proc remoteDeviceKey*(): DeviceKey =
  DeviceKey(kind: dkRemote)

proc unknownLocalDeviceKey*(): DeviceKey =
  DeviceKey(kind: dkUnknownLocal)

proc keyString*(key: DeviceKey): string =
  case key.kind
  of dkDevice:
    "device:" & key.deviceId
  of dkRemote:
    "remote"
  of dkUnknownLocal:
    "unknown_local"

proc setStatusMsg*(value: string): StatusMsg =
  StatusMsg(kind: smSet, hasValue: true, value: value)

proc clearStatusMsg*(): StatusMsg =
  StatusMsg(kind: smSet, hasValue: false)

proc unchangedStatusMsg*(): StatusMsg =
  StatusMsg(kind: smUnchanged)

proc clear*(aggregator: var PresenceAggregator) =
  aggregator.devices.clear()

proc saturatingSub(a, b: uint64): uint64 =
  if b > a: 0'u64 else: a - b

proc stateRank*(state: string): int =
  case state
  of PresenceBusy:
    3
  of PresenceOnline:
    2
  of PresenceUnavailable:
    1
  else:
    0

proc effectiveDeviceState*(
  state: string;
  lastActiveAge, idleTimeoutMs, offlineTimeoutMs: uint64;
): string =
  case state
  of PresenceBusy, PresenceOnline:
    if lastActiveAge >= idleTimeoutMs: PresenceUnavailable else: state
  of PresenceUnavailable:
    if lastActiveAge >= offlineTimeoutMs: PresenceOffline else: PresenceUnavailable
  of PresenceOffline:
    PresenceOffline
  else:
    state

proc update*(
  aggregator: var PresenceAggregator;
  userId: string;
  deviceKey: DeviceKey;
  state: string;
  currentlyActive = false;
  lastActiveAgo: uint64 = 0'u64;
  statusMsg = unchangedStatusMsg();
  nowMs: uint64;
) =
  var userDevices =
    if userId in aggregator.devices:
      aggregator.devices[userId]
    else:
      initTable[string, DevicePresence]()

  let key = deviceKey.keyString()
  let lastActiveTs = saturatingSub(nowMs, lastActiveAgo)
  var presence =
    if key in userDevices:
      userDevices[key]
    else:
      DevicePresence(
        state: state,
        currentlyActive: currentlyActive,
        lastActiveTs: lastActiveTs,
        lastUpdateTs: nowMs,
      )

  presence.state = state
  presence.currentlyActive = currentlyActive
  presence.lastActiveTs = lastActiveTs
  presence.lastUpdateTs = nowMs
  if statusMsg.kind == smSet:
    presence.hasStatusMsg = statusMsg.hasValue
    presence.statusMsg = if statusMsg.hasValue: statusMsg.value else: ""

  userDevices[key] = presence
  aggregator.devices[userId] = userDevices

proc aggregate*(
  aggregator: var PresenceAggregator;
  userId: string;
  nowMs, idleTimeoutMs, offlineTimeoutMs: uint64;
): AggregatedPresence =
  if userId notin aggregator.devices:
    return AggregatedPresence(state: PresenceOffline, lastActiveTs: nowMs, deviceCount: 0)

  var retained = initTable[string, DevicePresence]()
  var bestState = PresenceOffline
  var bestRank = stateRank(bestState)
  var anyActive = false
  var lastActiveTs = 0'u64
  var latestStatusTs = 0'u64
  var latestStatus = ""
  var hasLatestStatus = false

  for key, device in aggregator.devices[userId]:
    let lastActiveAge = saturatingSub(nowMs, device.lastActiveTs)
    let lastUpdateAge = saturatingSub(nowMs, device.lastUpdateTs)
    let effective = effectiveDeviceState(device.state, lastActiveAge, idleTimeoutMs, offlineTimeoutMs)
    let rank = stateRank(effective)
    if rank > bestRank:
      bestRank = rank
      bestState = effective

    if (effective == PresenceOnline or effective == PresenceBusy) and
        device.currentlyActive and lastActiveAge < idleTimeoutMs:
      anyActive = true

    if device.hasStatusMsg and device.statusMsg.len > 0 and
        (not hasLatestStatus or device.lastUpdateTs > latestStatusTs):
      hasLatestStatus = true
      latestStatusTs = device.lastUpdateTs
      latestStatus = device.statusMsg

    if device.lastActiveTs > lastActiveTs:
      lastActiveTs = device.lastActiveTs

    if lastUpdateAge < offlineTimeoutMs:
      retained[key] = device

  if retained.len == 0:
    aggregator.devices.del(userId)
    return AggregatedPresence(state: PresenceOffline, lastActiveTs: nowMs, deviceCount: 0)

  aggregator.devices[userId] = retained
  AggregatedPresence(
    state: bestState,
    currentlyActive: anyActive,
    lastActiveTs: if lastActiveTs == 0'u64: nowMs else: lastActiveTs,
    hasStatusMsg: hasLatestStatus,
    statusMsg: latestStatus,
    deviceCount: retained.len,
  )

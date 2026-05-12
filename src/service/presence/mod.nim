const
  RustPath* = "service/presence/mod.rs"
  RustCrate* = "service"

import std/[json, tables]

import service/presence/aggregate
import service/presence/data as presence_data
import service/presence/presence as presence_model

export aggregate, presence_data, presence_model

type
  PresenceService* = object
    idleTimeoutMs*: uint64
    offlineTimeoutMs*: uint64
    data*: PresenceData
    devicePresence*: PresenceAggregator
    lastSyncSeen*: Table[string, uint64]

proc initPresenceService*(
  idleTimeoutMs = 300_000'u64;
  offlineTimeoutMs = 1_800_000'u64;
): PresenceService =
  PresenceService(
    idleTimeoutMs: idleTimeoutMs,
    offlineTimeoutMs: offlineTimeoutMs,
    data: initPresenceData(),
    devicePresence: initPresenceAggregator(),
    lastSyncSeen: initTable[string, uint64](),
  )

proc noteSync*(service: var PresenceService; userId: string; nowMs: uint64) =
  service.lastSyncSeen[userId] = nowMs

proc lastSyncGapMs*(service: PresenceService; userId: string; nowMs: uint64): tuple[ok: bool, gap: uint64] =
  if userId notin service.lastSyncSeen:
    return (false, 0'u64)
  let seen = service.lastSyncSeen[userId]
  (true, if seen > nowMs: 0'u64 else: nowMs - seen)

proc getPresence*(service: PresenceService; userId: string; nowMs: uint64): tuple[ok: bool, event: JsonNode] =
  let fetched = service.data.getPresence(userId, nowMs)
  if not fetched.ok:
    return (false, newJObject())
  (true, fetched.event)

proc removePresence*(service: var PresenceService; userId: string) =
  service.data.removePresence(userId)

proc presenceSince*(
  service: PresenceService;
  since: uint64;
  upper = high(uint64);
): seq[PresenceRecord] =
  service.data.presenceSince(since, upper)

proc setPresence*(
  service: var PresenceService;
  userId: string;
  state: string;
  currentlyActive = false;
  lastActiveAgo: uint64 = 0'u64;
  statusMsg = "";
  hasStatusMsg = false;
  nowMs: uint64;
): PresenceSetResult =
  service.data.setPresence(
    userId,
    state,
    currentlyActive,
    lastActiveAgo,
    statusMsg,
    hasStatusMsg,
    nowMs,
  )

proc setPresenceForDevice*(
  service: var PresenceService;
  userId, deviceId, state: string;
  statusMsg = "";
  hasStatusMsg = false;
  nowMs: uint64;
): PresenceSetResult =
  service.devicePresence.update(
    userId,
    deviceKey(deviceId),
    state,
    currentlyActive = state == PresenceOnline,
    lastActiveAgo = 0'u64,
    statusMsg = if hasStatusMsg: setStatusMsg(statusMsg) else: clearStatusMsg(),
    nowMs = nowMs,
  )
  let aggregated = service.devicePresence.aggregate(
    userId,
    nowMs,
    service.idleTimeoutMs,
    service.offlineTimeoutMs,
  )
  service.setPresence(
    userId,
    aggregated.state,
    aggregated.currentlyActive,
    nowMs - aggregated.lastActiveTs,
    aggregated.statusMsg,
    aggregated.hasStatusMsg,
    nowMs,
  )

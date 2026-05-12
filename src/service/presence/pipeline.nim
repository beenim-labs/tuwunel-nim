const
  RustPath* = "service/presence/pipeline.rs"
  RustCrate* = "service"

import service/presence/aggregate

type
  RefreshSkipDecision* = tuple[skip: bool, count: uint64, lastActiveAgo: uint64]
  TimerFired* = tuple[userId: string, count: uint64]

proc refreshSkipDecision*(
  refreshWindowMs: uint64;
  hasLastEvent: bool;
  lastActiveAgo: uint64;
  hasLastCount: bool;
  lastCount: uint64;
): RefreshSkipDecision =
  if not hasLastEvent or not hasLastCount:
    return (false, 0'u64, 0'u64)
  if lastActiveAgo < refreshWindowMs:
    return (true, lastCount, lastActiveAgo)
  (false, 0'u64, 0'u64)

proc timerIsStale*(expectedCount, currentCount: uint64): bool =
  expectedCount != currentCount

proc deviceKeyForPresence*(deviceId = ""; isRemote = false): DeviceKey =
  if isRemote:
    return remoteDeviceKey()
  if deviceId.len == 0:
    return unknownLocalDeviceKey()
  deviceKey(deviceId)

proc timeoutForState*(state: string; idleTimeoutMs, offlineTimeoutMs: uint64): uint64 =
  if state == PresenceOnline:
    idleTimeoutMs
  else:
    offlineTimeoutMs

proc presenceTimer*(userId: string; count: uint64): TimerFired =
  (userId, count)

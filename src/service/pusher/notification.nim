const
  RustPath* = "service/pusher/notification.rs"
  RustCrate* = "service"

import std/[strutils, tables]

import "service/pusher/mod" as pusher_service

type
  ThreadCounts* = Table[string, tuple[notifications: uint64, highlights: uint64]]
  ThreadLastReads* = Table[string, uint64]

proc saturatingAdd(a, b: uint64): uint64 =
  let sum = a + b
  if sum < a: high(uint64) else: sum

proc zeroCount(service: var PusherService; userId, roomId, threadRoot: string) =
  service.notificationCounts[roomCountKey(userId, roomId, threadRoot)] = 0'u64
  service.highlightCounts[roomCountKey(userId, roomId, threadRoot)] = 0'u64

proc resetNotificationCounts*(service: var PusherService; userId, roomId: string) =
  let count = service.nextCountValue()
  service.zeroCount(userId, roomId, "")
  service.lastNotificationRead[roomReadKey(roomId, userId)] = count
  discard service.suppressed.clearSuppressedRoom(userId, roomId)

proc resetMainNotificationCounts*(service: var PusherService; userId, roomId: string) =
  service.resetNotificationCounts(userId, roomId)

proc resetThreadNotificationCounts*(
  service: var PusherService;
  userId, roomId, threadRoot: string;
) =
  let count = service.nextCountValue()
  service.zeroCount(userId, roomId, threadRoot)
  service.lastNotificationRead[roomReadKey(roomId, userId, threadRoot)] = count

proc clearAllThreadNotificationCounts*(service: var PusherService; userId, roomId: string) =
  let countPrefix = roomCountKey(userId, roomId) & "\0"
  let readPrefix = roomReadKey(roomId, userId) & "\0"
  var doomed: seq[string] = @[]
  for key in service.notificationCounts.keys:
    if key.startsWith(countPrefix):
      doomed.add(key)
  for key in doomed:
    service.notificationCounts.del(key)
  doomed = @[]
  for key in service.highlightCounts.keys:
    if key.startsWith(countPrefix):
      doomed.add(key)
  for key in doomed:
    service.highlightCounts.del(key)
  doomed = @[]
  for key in service.lastNotificationRead.keys:
    if key.startsWith(readPrefix):
      doomed.add(key)
  for key in doomed:
    service.lastNotificationRead.del(key)

proc resetNotificationCountsForThread*(
  service: var PusherService;
  userId, roomId, threadRootKind: string;
  threadRoot = "";
) =
  case threadRootKind
  of "main":
    service.resetMainNotificationCounts(userId, roomId)
  of "thread":
    service.resetThreadNotificationCounts(userId, roomId, threadRoot)
  else:
    service.resetNotificationCounts(userId, roomId)
    service.clearAllThreadNotificationCounts(userId, roomId)

proc notificationCount*(service: PusherService; userId, roomId: string): uint64 =
  service.notificationCounts.getOrDefault(roomCountKey(userId, roomId), 0'u64)

proc highlightCount*(service: PusherService; userId, roomId: string): uint64 =
  service.highlightCounts.getOrDefault(roomCountKey(userId, roomId), 0'u64)

proc threadNotificationCounts*(service: PusherService; userId, roomId: string): ThreadCounts =
  result = initTable[string, tuple[notifications: uint64, highlights: uint64]]()
  let prefix = roomCountKey(userId, roomId) & "\0"
  for key, count in service.notificationCounts:
    if key.startsWith(prefix):
      let root = key[prefix.len .. ^1]
      var entry = result.getOrDefault(root, (0'u64, 0'u64))
      entry.notifications = entry.notifications.saturatingAdd(count)
      result[root] = entry
  for key, count in service.highlightCounts:
    if key.startsWith(prefix):
      let root = key[prefix.len .. ^1]
      var entry = result.getOrDefault(root, (0'u64, 0'u64))
      entry.highlights = entry.highlights.saturatingAdd(count)
      result[root] = entry

proc lastNotificationRead*(service: PusherService; userId, roomId: string): tuple[ok: bool, count: uint64] =
  let key = roomReadKey(roomId, userId)
  if key notin service.lastNotificationRead:
    return (false, 0'u64)
  (true, service.lastNotificationRead[key])

proc threadLastNotificationReads*(service: PusherService; userId, roomId: string): ThreadLastReads =
  result = initTable[string, uint64]()
  let prefix = roomReadKey(roomId, userId) & "\0"
  for key, count in service.lastNotificationRead:
    if key.startsWith(prefix):
      result[key[prefix.len .. ^1]] = count

proc deleteRoomNotificationRead*(service: var PusherService; roomId: string) =
  let prefix = roomId & "\0"
  var doomed: seq[string] = @[]
  for key in service.lastNotificationRead.keys:
    if key.startsWith(prefix):
      doomed.add(key)
  for key in doomed:
    service.lastNotificationRead.del(key)

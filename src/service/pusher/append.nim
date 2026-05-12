const
  RustPath* = "service/pusher/append.rs"
  RustCrate* = "service"

import "service/pusher/mod" as pusher_service
import std/tables

proc saturatingAdd(a, b: uint64): uint64 =
  let sum = a + b
  if sum < a: high(uint64) else: sum

proc incrementNotificationCount*(
  service: var PusherService;
  userId, roomId: string;
) =
  let key = roomCountKey(userId, roomId)
  service.notificationCounts[key] = saturatingAdd(service.notificationCounts.getOrDefault(key, 0'u64), 1'u64)

proc incrementHighlightCount*(
  service: var PusherService;
  userId, roomId: string;
) =
  let key = roomCountKey(userId, roomId)
  service.highlightCounts[key] = saturatingAdd(service.highlightCounts.getOrDefault(key, 0'u64), 1'u64)

proc incrementThreadNotificationCount*(
  service: var PusherService;
  userId, roomId, threadRoot: string;
) =
  let key = roomCountKey(userId, roomId, threadRoot)
  service.notificationCounts[key] = saturatingAdd(service.notificationCounts.getOrDefault(key, 0'u64), 1'u64)

proc incrementThreadHighlightCount*(
  service: var PusherService;
  userId, roomId, threadRoot: string;
) =
  let key = roomCountKey(userId, roomId, threadRoot)
  service.highlightCounts[key] = saturatingAdd(service.highlightCounts.getOrDefault(key, 0'u64), 1'u64)

proc storeNotification*(
  service: var PusherService;
  userId, shortRoomId: string;
  count: uint64;
  actions: openArray[string];
  ts = 0'u64;
  tag = "";
) =
  var entries = service.notifications.getOrDefault(userId, @[])
  var storedActions: seq[string] = @[]
  for action in actions:
    storedActions.add(action)
  entries.add((count, Notified(
    ts: ts,
    shortRoomId: shortRoomId,
    tag: tag,
    actions: storedActions,
  )))
  service.notifications[userId] = entries

proc appendNotification*(
  service: var PusherService;
  userId, roomId, shortRoomId: string;
  pduCount: uint64;
  notify, highlight: bool;
  threadRoot = "";
  actions: openArray[string] = [];
  ts = 0'u64;
) =
  if notify:
    if threadRoot.len == 0:
      service.incrementNotificationCount(userId, roomId)
    else:
      service.incrementThreadNotificationCount(userId, roomId, threadRoot)
  if highlight:
    if threadRoot.len == 0:
      service.incrementHighlightCount(userId, roomId)
    else:
      service.incrementThreadHighlightCount(userId, roomId, threadRoot)
  if notify or highlight:
    var storedActions: seq[string] = @[]
    if actions.len == 0:
      storedActions.add("notify")
    else:
      for action in actions:
        storedActions.add(action)
    service.storeNotification(userId, shortRoomId, pduCount, storedActions, ts)

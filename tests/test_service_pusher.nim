import std/[json, strutils, tables, unittest]

import "service/pusher/mod" as pusher_service
import service/pusher/append as pusher_append
import service/pusher/notification as pusher_notification
import service/pusher/request as pusher_request
import service/pusher/send as pusher_send
import service/pusher/suppressed as pusher_suppressed

suite "Service pusher parity":
  test "pusher request validation follows Matrix length and URL policy":
    let valid = pusher_request.httpPusher("app", "push", "https://push.example/_matrix/push/v1/notify")
    check pusher_request.validatePusher(valid).ok
    check pusher_request.pushGatewayDestination(
      "https://push.example/_matrix/push/v1/notify",
      "/_matrix/push/v1/notify",
    ) == "https://push.example"

    let longPushkey = pusher_request.httpPusher("app", repeat("x", 513), "https://push.example")
    check pusher_request.validatePusher(longPushkey).message == "Push key length cannot be greater than 512 bytes."

    let longApp = pusher_request.httpPusher(repeat("a", 65), "push", "https://push.example")
    check pusher_request.validatePusher(longApp).message == "App ID length cannot be greater than 64 bytes."

    let badScheme = pusher_request.httpPusher("app", "push", "ftp://push.example")
    check pusher_request.validatePusher(badScheme).message.contains("HTTP/HTTPS")

  test "pusher service stores pushers by sender and device and delete clears suppression":
    var service = pusher_service.initPusherService()
    let sender = "@alice:example.test"
    let pusher = pusher_request.httpPusher("app", "push-a", "https://push.example")

    check pusher_service.setPusher(service, sender, "DEVICE", pusher).ok
    check pusher_service.getPusher(service, sender, "push-a").ok
    check pusher_service.getPusherDevice(service, "push-a").deviceId == "DEVICE"
    check pusher_service.getPushkeys(service, sender) == @["push-a"]
    check pusher_service.getDevicePushkeys(service, sender, "DEVICE") == @["push-a"]

    check pusher_suppressed.queueSuppressedPush(service.suppressed, sender, "push-a", "!room:example.test", "$1")
    pusher_service.deletePusher(service, sender, "push-a")
    check pusher_service.getPushkeys(service, sender).len == 0
    check pusher_suppressed.takeSuppressedForPushkey(service.suppressed, sender, "push-a").len == 0

  test "suppressed queue deduplicates, drains by pushkey, and clears rooms":
    var queue = pusher_suppressed.initSuppressedQueue()
    let userId = "@alice:example.test"

    check pusher_suppressed.queueSuppressedPush(queue, userId, "push-a", "!room:example.test", "$1")
    check not pusher_suppressed.queueSuppressedPush(queue, userId, "push-a", "!room:example.test", "$1")
    check pusher_suppressed.queueSuppressedPush(queue, userId, "push-a", "!room:example.test", "$2")
    check pusher_suppressed.queueSuppressedPush(queue, userId, "push-a", "!other:example.test", "$3")

    check pusher_suppressed.clearSuppressedRoom(queue, userId, "!other:example.test") == 1
    let drained = pusher_suppressed.takeSuppressedForPushkey(queue, userId, "push-a")
    check drained.len == 1
    check drained[0].roomId == "!room:example.test"
    check drained[0].pduIds == @["$1", "$2"]

  test "notification counts separate main timeline and thread rows":
    var service = pusher_service.initPusherService()
    let userId = "@alice:example.test"
    let roomId = "!room:example.test"

    pusher_append.appendNotification(
      service,
      userId,
      roomId,
      "1",
      10'u64,
      notify = true,
      highlight = true,
      actions = ["notify", "highlight"],
      ts = 42'u64,
    )
    check pusher_notification.notificationCount(service, userId, roomId) == 1'u64
    check pusher_notification.highlightCount(service, userId, roomId) == 1'u64
    check service.notifications[userId][0].notified.actions == @["notify", "highlight"]

    pusher_append.appendNotification(
      service,
      userId,
      roomId,
      "1",
      11'u64,
      notify = true,
      highlight = false,
      threadRoot = "$thread",
    )
    let threadCounts = pusher_notification.threadNotificationCounts(service, userId, roomId)
    check threadCounts["$thread"].notifications == 1'u64
    check threadCounts["$thread"].highlights == 0'u64

    pusher_notification.resetThreadNotificationCounts(service, userId, roomId, "$thread")
    check pusher_notification.threadNotificationCounts(service, userId, roomId)["$thread"].notifications == 0'u64
    check pusher_notification.threadLastNotificationReads(service, userId, roomId).hasKey("$thread")

    pusher_notification.resetNotificationCountsForThread(service, userId, roomId, "unthreaded")
    check pusher_notification.notificationCount(service, userId, roomId) == 0'u64
    check pusher_notification.threadNotificationCounts(service, userId, roomId).len == 0

  test "push notification payload honors event-id-only and badge-count settings":
    let event = %*{
      "event_id": "$event",
      "room_id": "!room:example.test",
      "sender": "@alice:example.test",
      "type": "m.room.message",
      "content": {"body": "hello"},
    }
    let full = pusher_request.httpPusher("app", "push", "https://push.example")
    let payload = pusher_send.notificationPayload(3'u64, full, event, tweaks = ["sound:default"])
    check payload["notification"]["counts"]["unread"].getInt == 3
    check payload["notification"]["prio"].getStr == "high"
    check payload["notification"]["content"]["body"].getStr == "hello"

    let eventIdOnly = pusher_request.httpPusher(
      "app",
      "push",
      "https://push.example",
      data = %*{"disable_badge_count": true},
      format = "event_id_only",
    )
    let minimal = pusher_send.notificationPayload(9'u64, eventIdOnly, event, tweaks = ["sound:default"])
    check not minimal["notification"].hasKey("counts")
    check not minimal["notification"].hasKey("content")
    check not minimal["notification"]["devices"][0].hasKey("tweaks")
    check pusher_send.pushNoticePolicy(["notify"]).notify
    check not pusher_send.pushNoticePolicy(["notify", "dont_notify"]).ok

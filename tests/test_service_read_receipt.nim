import std/[json, unittest]

import "service/rooms/read_receipt/mod" as receipt_service

proc receiptEvent(roomId, eventId, receiptType, userId: string; ts = 1'i64; threadId = ""): JsonNode =
  var userEntry = %*{"ts": ts}
  if threadId.len > 0:
    userEntry["thread_id"] = %threadId
  var users = newJObject()
  users[userId] = userEntry
  var receiptTypes = newJObject()
  receiptTypes[receiptType] = users
  var content = newJObject()
  content[eventId] = receiptTypes
  %*{"type": "m.receipt", "room_id": roomId, "content": content}

suite "Service read receipt parity":
  test "read receipt update replaces same user/thread and emits appservice/federation side effects":
    var service = receipt_service.initReadReceiptService()
    receipt_service.setUserLocal(service, "@alice:localhost", true)

    let first = receipt_service.readreceiptUpdate(
      service,
      "@alice:localhost",
      "!room:localhost",
      receiptEvent("!room:localhost", "$event1", "m.read", "@alice:localhost", ts = 10),
    )
    let second = receipt_service.readreceiptUpdate(
      service,
      "@alice:localhost",
      "!room:localhost",
      receiptEvent("!room:localhost", "$event2", "m.read", "@alice:localhost", ts = 20),
    )

    check first == 1'u64
    check second == 2'u64
    let receipts = receipt_service.readreceiptsSince(service, "!room:localhost", 0'u64)
    check receipts.len == 1
    check receipts[0].streamPos == second
    check receipts[0].event["content"].hasKey("$event2")
    check not receipts[0].event.hasKey("room_id")
    check service.sentAppserviceEdus.len == 2
    check service.flushedRooms == @["!room:localhost", "!room:localhost"]

  test "threaded receipts coexist with unthreaded replacement and support bounded sync windows":
    var service = receipt_service.initReadReceiptService()
    discard receipt_service.readreceiptUpdate(
      service,
      "@alice:localhost",
      "!room:localhost",
      receiptEvent("!room:localhost", "$unthreaded", "m.read", "@alice:localhost"),
    )
    let threaded = receipt_service.readreceiptUpdate(
      service,
      "@alice:localhost",
      "!room:localhost",
      receiptEvent("!room:localhost", "$threaded", "m.read", "@alice:localhost", threadId = "$thread"),
    )
    let bob = receipt_service.readreceiptUpdate(
      service,
      "@bob:localhost",
      "!room:localhost",
      receiptEvent("!room:localhost", "$bob", "m.read", "@bob:localhost"),
    )

    check receipt_service.readreceiptsSince(service, "!room:localhost", 0'u64, threaded).len == 2
    check receipt_service.lastReceiptCount(service, "!room:localhost").count == bob
    check receipt_service.lastReceiptCount(service, "!room:localhost", userId = "@alice:localhost").count == threaded

  test "private read markers handle legacy and threaded rows and unthreaded supersedes threads":
    var service = receipt_service.initReadReceiptService()
    receipt_service.registerPduEvent(service.db, "!room:localhost", 5'u64, "$event5")
    receipt_service.registerPduEvent(service.db, "!room:localhost", 6'u64, "$event6")

    discard receipt_service.privateReadSet(service, "!room:localhost", "@alice:localhost", 5'u64, "$thread")
    check receipt_service.privateReadGet(service, "!room:localhost", "@alice:localhost")[0]["content"]["$event5"]["m.read.private"]["@alice:localhost"]["thread_id"].getStr == "$thread"
    let update = receipt_service.privateReadSet(service, "!room:localhost", "@alice:localhost", 6'u64)
    check receipt_service.lastPrivateReadUpdate(service, "@alice:localhost", "!room:localhost") == update

    let privateEvents = receipt_service.privateReadGet(service, "!room:localhost", "@alice:localhost")
    check privateEvents.len == 1
    check privateEvents[0]["content"].hasKey("$event6")
    check receipt_service.privateReadGetCount(service, "!room:localhost", "@alice:localhost").count == 6'u64

  test "pack and delete mirror Matrix sync receipt shape":
    var service = receipt_service.initReadReceiptService()
    let first = receiptEvent("!room:localhost", "$one", "m.read", "@alice:localhost")
    let second = receiptEvent("!room:localhost", "$two", "m.read", "@bob:localhost")
    let packed = receipt_service.packReceipts(@[first, second])
    check packed["type"].getStr == "m.receipt"
    check packed["content"].hasKey("$one")
    check packed["content"].hasKey("$two")

    discard receipt_service.readreceiptUpdate(service, "@alice:localhost", "!room:localhost", first)
    discard receipt_service.privateReadSet(service, "!room:localhost", "@alice:localhost", 1'u64)
    check receipt_service.deleteAllReadReceipts(service, "!room:localhost").ok
    check receipt_service.readreceiptsSince(service, "!room:localhost", 0'u64).len == 0
    check not receipt_service.privateReadGetCount(service, "!room:localhost", "@alice:localhost").ok

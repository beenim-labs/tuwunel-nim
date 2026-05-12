import std/[json, options, tables, unittest]

import "service/rooms/threads/mod" as thread_service

proc event(
  eventId, sender: string;
  streamPos: uint64;
  roomId = "!room:localhost";
  content: JsonNode = newJObject();
  txn = "";
): thread_service.ThreadEvent =
  thread_service.ThreadEvent(
    eventId: eventId,
    roomId: roomId,
    sender: sender,
    streamPos: streamPos,
    content: content,
    unsigned: newJObject(),
    transactionId: txn,
  )

suite "Service threads parity":
  test "thread id resolution walks relation chains up to the Rust hop limit":
    var service = thread_service.initThreadService()
    thread_service.addEvent(service, event("$root", "@alice:localhost", 1'u64))
    thread_service.addEvent(service, event("$reply", "@bob:localhost", 2'u64, content = %*{
      "m.relates_to": {"rel_type": "m.thread", "event_id": "$root"},
    }))
    thread_service.addEvent(service, event("$annotation", "@carol:localhost", 3'u64, content = %*{
      "m.relates_to": {"rel_type": "m.annotation", "event_id": "$reply"},
    }))

    check thread_service.getThreadIdForEvent(service, "$reply").get() == "$root"
    check thread_service.getThreadIdForEvent(service, "$annotation").get() == "$root"
    check thread_service.getThreadIdForEvent(service, "$root").isNone

  test "addToThread updates root bundled relation and participant set":
    var service = thread_service.initThreadService()
    thread_service.addEvent(service, event("$root", "@alice:localhost", 1'u64, txn = "txn-root"))
    let reply = event("$reply", "@bob:localhost", 2'u64, content = %*{
      "body": "reply",
      "m.relates_to": {"rel_type": "m.thread", "event_id": "$root"},
    })
    check thread_service.addToThread(service, "$root", reply).ok

    let root = service.events["$root"]
    check root.unsigned["m.relations"]["m.thread"]["count"].getInt == 1
    check root.unsigned["m.relations"]["m.thread"]["latest_event"]["event_id"].getStr == "$reply"
    check root.unsigned["m.relations"]["m.thread"]["current_user_participated"].getBool
    check thread_service.getParticipants(service, "$root").users == @["@alice:localhost", "@bob:localhost"]

  test "threadsUntil returns roots in reverse stream order and strips other users transaction ids":
    var service = thread_service.initThreadService()
    thread_service.addEvent(service, event("$root1", "@alice:localhost", 1'u64, txn = "own"))
    thread_service.addEvent(service, event("$root2", "@bob:localhost", 3'u64, txn = "other"))
    check thread_service.updateParticipants(service, "$root1", @["@alice:localhost"]).ok
    check thread_service.updateParticipants(service, "$root2", @["@bob:localhost"]).ok

    let threads = thread_service.threadsUntil(service, "@alice:localhost", "!room:localhost", 10'u64)
    check threads.len == 2
    check threads[0].eventId == "$root2"
    check threads[0].transactionId == ""
    check threads[1].eventId == "$root1"
    check threads[1].transactionId == "own"

    check thread_service.deleteAllRoomsThreads(service, "!room:localhost").ok
    check thread_service.threadsUntil(service, "@alice:localhost", "!room:localhost", 10'u64).len == 0

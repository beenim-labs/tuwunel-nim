import std/[json, unittest]

import "service/rooms/typing/mod" as typing_service

suite "Service typing parity":
  test "typing add remove and timeout update room counts and EDUs":
    var service = typing_service.initTypingService()
    check typing_service.typingAdd(
      service,
      "@alice:localhost",
      "!room:localhost",
      timeout = 10_000'u64,
    ).ok
    let firstUpdate = typing_service.lastTypingUpdateCount(service, "!room:localhost")
    check firstUpdate == 1'u64
    check typing_service.typingUsersForUser(service, "!room:localhost", "@bob:localhost") == @["@alice:localhost"]
    check service.sentFederationEdus[^1]["content"]["typing"].getBool == true
    check service.sentAppserviceEdus[^1]["content"]["user_ids"][0].getStr == "@alice:localhost"

    check typing_service.typingAdd(
      service,
      "@carol:localhost",
      "!room:localhost",
      timeout = 20_000'u64,
    ).ok
    typing_service.ignoreUser(service, "@bob:localhost", "@alice:localhost")
    check typing_service.typingUsersForUser(service, "!room:localhost", "@bob:localhost") == @["@carol:localhost"]

    check typing_service.typingsMaintain(service, "!room:localhost", 15_000'u64) == 1
    check typing_service.typingUsersForUser(service, "!room:localhost", "@carol:localhost") == @["@carol:localhost"]
    check service.sentFederationEdus[^1]["content"]["typing"].getBool == false

    check typing_service.typingRemove(service, "@carol:localhost", "!room:localhost").ok
    check typing_service.typingUsersForUser(service, "!room:localhost", "@bob:localhost").len == 0
    check typing_service.waitForUpdateObserved(service, "!room:localhost", firstUpdate)

  test "outgoing federation typing can be disabled while appservice EDU still records":
    var service = typing_service.initTypingService(allowOutgoingTyping = false)
    check typing_service.typingAdd(
      service,
      "@alice:localhost",
      "!room:localhost",
      timeout = 10_000'u64,
    ).ok
    check service.sentFederationEdus.len == 0
    check service.sentAppserviceEdus.len == 1
    check typing_service.typingContent(service, "!room:localhost")["content"]["user_ids"][0].getStr == "@alice:localhost"

import std/[httpcore, json, strutils, tables, unittest]

import "service/appservice/mod" as appservice

proc bridgeRegistration(id = "bridge"; asToken = "as-secret"): appservice.AppserviceRegistration =
  appservice.AppserviceRegistration(
    id: id,
    url: "http://127.0.0.1:29336/",
    asToken: asToken,
    hsToken: "hs-secret",
    senderLocalpart: "bridgebot",
    receiveEphemeral: true,
    deviceManagement: true,
    aliases: @[appservice.namespace("^#bridge_.*:example\\.test$", exclusive = true)],
    users: @[appservice.namespace("^@bridge_.*:example\\.test$", exclusive = true)],
    rooms: @[appservice.namespace("^!room.*:example\\.test$", exclusive = false)],
  )

suite "Service appservice parity":
  test "namespace regex separates exclusive and non-exclusive rights":
    let namespaces = appservice.initNamespaceRegex(
      caseSensitive = false,
      values = [
        appservice.namespace("^@bridge_.*:example\\.test$", exclusive = true),
        appservice.namespace("^@bot_.*:example\\.test$", exclusive = false),
      ],
    )
    check appservice.isExclusiveMatch(namespaces, "@Bridge_Alice:example.test")
    check appservice.isMatch(namespaces, "@bot_alice:example.test")
    check not appservice.isExclusiveMatch(namespaces, "@bot_alice:example.test")

    let rooms = appservice.initNamespaceRegex(
      caseSensitive = true,
      values = [appservice.namespace("^!ROOM:example\\.test$", exclusive = true)],
    )
    check appservice.isExclusiveMatch(rooms, "!ROOM:example.test")
    check not appservice.isExclusiveMatch(rooms, "!room:example.test")

  test "registration info resolves sender and local-only user namespace matches":
    let info = appservice.newRegistrationInfo(bridgeRegistration(), "example.test")
    check info.sender == "@bridgebot:example.test"
    check appservice.isUserMatch(info, "@bridgebot:example.test")
    check appservice.isUserMatch(info, "@bridge_alice:example.test")
    check appservice.isExclusiveUserMatch(info, "@bridge_alice:example.test")
    check not appservice.isUserMatch(info, "@bridge_alice:remote.test")
    check appservice.isExclusiveMatch(info.aliases, "#bridge_room:example.test")
    check appservice.isMatch(info.rooms, "!room123:example.test")

  test "service loads, registers, finds and unregisters appservices":
    var service = appservice.initAppserviceService("example.test")
    let loaded = appservice.loadAppservice(service, bridgeRegistration())
    check loaded.ok
    check service.knownUsers.hasKey("@bridgebot:example.test")
    check appservice.iterIds(service) == @["bridge"]
    check appservice.findFromAccessToken(service, "as-secret").ok
    check appservice.isExclusiveUserId(service, "@bridge_alice:example.test")
    check appservice.isExclusiveAlias(service, "#bridge_room:example.test")

    let dupId = appservice.loadAppservice(service, bridgeRegistration(asToken = "other-secret"))
    check not dupId.ok
    check "Duplicate id" in dupId.message

    let dupToken = appservice.loadAppservice(service, bridgeRegistration(id = "other", asToken = "as-secret"))
    check not dupToken.ok
    check "Duplicate as_token" in dupToken.message

    let cannotUnregisterConfig = appservice.unregisterAppservice(service, "bridge")
    check not cannotUnregisterConfig.ok
    check cannotUnregisterConfig.message == "Cannot unregister config appservice"

    let registered = appservice.registerAppservice(service, bridgeRegistration(id = "db-bridge", asToken = "db-token"))
    check registered.ok
    check appservice.iterDbIds(service) == @["db-bridge"]
    check appservice.getDbRegistration(service, "db-bridge").ok

    let unregistered = appservice.unregisterAppservice(service, "db-bridge")
    check unregistered.ok
    check service.cleanupRequests == @["db-bridge"]
    check not appservice.getRegistration(service, "db-bridge").ok

  test "request builder skips disabled URLs and sends bearer auth":
    let reg = bridgeRegistration()
    let request = appservice.buildAppserviceRequest(
      reg,
      "/_matrix/app/v1/transactions/t1",
      %*{"events": []},
    )
    check not request.skipped
    check request.url == "http://127.0.0.1:29336/_matrix/app/v1/transactions/t1"
    check "access_token=" notin request.url
    check request.headers["Authorization"] == "Bearer hs-secret"
    check request.headers["Content-Type"] == "application/json"
    check request.body["events"].len == 0

    var disabled = reg
    disabled.url = "null"
    check appservice.buildAppserviceRequest(disabled, "/x").skipped
    check appservice.appserviceResponsePolicy(Http200).ok
    check not appservice.appserviceResponsePolicy(Http500).ok
    check not appservice.appserviceResponsePolicy(Http200, validBody = false).ok

  test "append decisions include room membership, sender, state-key, alias and room namespace":
    let bridge = appservice.newRegistrationInfo(bridgeRegistration(), "example.test")
    let unrelated = appservice.AppservicePdu(
      pduId: "$1",
      eventId: "$1",
      roomId: "!other:example.test",
      sender: "@alice:example.test",
      kind: "m.room.message",
    )
    check not appservice.shouldAppendTo(bridge, unrelated)

    var inRoom = unrelated
    inRoom.appserviceInRoom = true
    check appservice.shouldAppendTo(bridge, inRoom)

    var bySender = unrelated
    bySender.sender = "@bridge_alice:example.test"
    check appservice.shouldAppendTo(bridge, bySender)

    var byStateKey = unrelated
    byStateKey.kind = "m.room.member"
    byStateKey.stateKey = "@bridge_alice:example.test"
    check appservice.shouldAppendTo(bridge, byStateKey)

    var byAlias = unrelated
    byAlias.aliases = @["#bridge_room:example.test"]
    check appservice.shouldAppendTo(bridge, byAlias)

    var byRoom = unrelated
    byRoom.roomId = "!room123:example.test"
    check appservice.shouldAppendTo(bridge, byRoom)

    let queued = appservice.appendPdu([bridge], byRoom)
    check queued == @[(registrationId: "bridge", pduId: "$1")]

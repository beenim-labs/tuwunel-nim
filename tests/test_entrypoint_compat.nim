import std/[json, locks, os, sets, strutils, tables, unittest]

include ../src/main/entrypoint

const EntrypointSource = staticRead("../src/main/entrypoint.nim")

proc newCompatState(statePath: string): ServerState =
  result = ServerState(
    statePath: statePath,
    serverName: "localhost",
    streamPos: 0,
    deliveryCounter: 0,
    roomCounter: 0,
    usersByName: initTable[string, string](),
    users: initTable[string, UserProfile](),
    tokens: initTable[string, AccessSession](),
    userTokens: initTable[string, seq[string]](),
    devices: initTable[string, DeviceRecord](),
    rooms: initTable[string, RoomData](),
    accountData: initTable[string, AccountDataRecord](),
    filters: initTable[string, JsonNode](),
    userJoinedRooms: initTable[string, HashSet[string]](),
    appserviceRegs: @[],
    appserviceByAsToken: initTable[string, AppserviceRegistration](),
    pendingDeliveries: @[],
    deliveryInFlight: 0,
    deliveryBaseMs: 100,
    deliveryMaxMs: 1000,
    deliveryMaxAttempts: 3,
    deliveryMaxInflight: 1,
    deliverySent: 0,
    deliveryFailed: 0,
    deliveryDeadLetters: 0
  )
  initLock(result.lock)

suite "entrypoint compat helpers":
  test "joinedMembersPayload includes only joined users with profile data":
    let statePath = getTempDir() / "tuwunel-entrypoint-compat-state.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    state.users["@alice:localhost"] = UserProfile(
      userId: "@alice:localhost",
      username: "alice",
      password: "",
      displayName: "Alice",
      avatarUrl: "mxc://localhost/alice"
    )
    state.users["@bob:localhost"] = UserProfile(
      userId: "@bob:localhost",
      username: "bob",
      password: "",
      displayName: "Bob",
      avatarUrl: ""
    )
    let room = RoomData(
      roomId: "!room:localhost",
      creator: "@alice:localhost",
      isDirect: true,
      members: {
        "@alice:localhost": "join",
        "@bob:localhost": "invite",
        "@carol:localhost": "join"
      }.toTable,
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )

    let payload = joinedMembersPayload(state, room)
    check payload["joined"].hasKey("@alice:localhost")
    check payload["joined"].hasKey("@carol:localhost")
    check not payload["joined"].hasKey("@bob:localhost")
    check payload["joined"]["@alice:localhost"]["display_name"].getStr("") == "Alice"
    check payload["joined"]["@alice:localhost"]["avatar_url"].getStr("") == "mxc://localhost/alice"

  test "media upload helpers persist data and metadata":
    let statePath = getTempDir() / "tuwunel-entrypoint-media-state.json"
    let mediaDir = mediaDirFromStatePath(statePath)
    if dirExists(mediaDir):
      for kind, entry in walkDir(mediaDir):
        if kind in {pcFile, pcLinkToFile}:
          removeFile(entry)
      removeDir(mediaDir)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if dirExists(mediaDir):
        for kind, entry in walkDir(mediaDir):
          if kind in {pcFile, pcLinkToFile}:
            removeFile(entry)
        removeDir(mediaDir)

    let mediaId = storeUploadedMedia(state, "hello", "text/plain", "hello.txt")
    check mediaId.startsWith("media_")
    check fileExists(mediaDataPath(state.statePath, mediaId))
    let meta = loadStoredMediaMeta(state, mediaId)
    check meta.ok
    check meta.contentType == "text/plain"
    check meta.fileName == "hello.txt"
    check readFile(mediaDataPath(state.statePath, mediaId)) == "hello"

  test "media path helpers recognize upload and download aliases":
    check isMediaUploadPath("/_matrix/media/v3/upload")
    check isMediaUploadPath("/_matrix/client/v1/media/upload")
    let parsed = mediaDownloadParts("/_matrix/client/v1/media/download/localhost/abc123/test.png")
    check parsed.ok
    check parsed.mediaId == "abc123"

  test "entrypoint only has one sync route handler":
    check EntrypointSource.count("if isSyncPath(path):") == 1

  test "entrypoint creates rooms with default power levels":
    check "\"m.room.power_levels\"" in EntrypointSource

  test "appendEventLocked indexes empty-key state events":
    let statePath = getTempDir() / "tuwunel-entrypoint-state-index.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    discard state.appendEventLocked(
      "!room:localhost",
      "@creator:localhost",
      "m.room.power_levels",
      "",
      defaultPowerLevelsContent("@creator:localhost")
    )
    check stateKey("m.room.power_levels", "") in state.rooms["!room:localhost"].stateByKey

  test "appendEventLocked stores top-level redacts for redaction events":
    let statePath = getTempDir() / "tuwunel-entrypoint-redact.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    let ev = state.appendEventLocked(
      "!room:localhost",
      "@creator:localhost",
      "m.room.redaction",
      "",
      %*{
        "reason": "Removed in Beenim",
        "delete_for_everyone": true,
        "redacts": "$target"
      },
      redacts = "$target"
    )

    check ev.redacts == "$target"
    let payload = ev.eventToJson()
    check payload["redacts"].getStr("") == "$target"
    check payload["content"]["redacts"].getStr("") == "$target"

  test "roomAndRedactFromPath parses client redaction routes":
    let parsedV3 = roomAndRedactFromPath("/_matrix/client/v3/rooms/%21room%3Alocalhost/redact/%24evt1/txn123")
    check parsedV3.roomId == "!room:localhost"
    check parsedV3.eventId == "$evt1"
    check parsedV3.txnId == "txn123"

    let parsedR0 = roomAndRedactFromPath("/_matrix/client/r0/rooms/%21room%3Alocalhost/redact/%24evt2/txn456")
    check parsedR0.roomId == "!room:localhost"
    check parsedR0.eventId == "$evt2"
    check parsedR0.txnId == "txn456"

  test "ensureDefaultPowerLevelsLocked repairs existing rooms":
    let statePath = getTempDir() / "tuwunel-entrypoint-power-repair.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    state.rooms["!room:localhost"] = RoomData(
      roomId: "!room:localhost",
      creator: "@creator:localhost",
      isDirect: true,
      members: {"@creator:localhost": "join"}.toTable,
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )

    check state.ensureDefaultPowerLevelsLocked("!room:localhost", "@viewer:localhost")
    let room = state.rooms["!room:localhost"]
    let key = stateKey("m.room.power_levels", "")
    check key in room.stateByKey
    check room.stateByKey[key].content["users"]["@creator:localhost"].getInt(0) == 100
    check roomStateArray(room).len == 1

  test "ensureDefaultJoinRulesLocked repairs existing rooms":
    let statePath = getTempDir() / "tuwunel-entrypoint-join-rules-repair.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    state.rooms["!room:localhost"] = RoomData(
      roomId: "!room:localhost",
      creator: "@creator:localhost",
      isDirect: true,
      members: {"@creator:localhost": "join"}.toTable,
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )

    check state.ensureDefaultJoinRulesLocked("!room:localhost", "@viewer:localhost")
    let room = state.rooms["!room:localhost"]
    let key = stateKey("m.room.join_rules", "")
    check key in room.stateByKey
    check room.stateByKey[key].content["join_rule"].getStr("") == "invite"

  test "entrypoint handles room join by id path":
    check "roomIdFromRoomsPath(path, \"join\")" in EntrypointSource

  test "entrypoint handles room messages path":
    check "roomIdFromRoomsPath(path, \"messages\")" in EntrypointSource

  test "filter and account-data path parsers cover stable client routes":
    let filterCreate = userFilterPathParts("/_matrix/client/v3/user/%40alice%3Alocalhost/filter")
    check filterCreate.ok
    check filterCreate.create
    check filterCreate.userId == "@alice:localhost"

    let filterGet = userFilterPathParts("/_matrix/client/r0/user/%40alice%3Alocalhost/filter/abcd")
    check filterGet.ok
    check not filterGet.create
    check filterGet.filterId == "abcd"

    let global = userAccountDataPathParts("/_matrix/client/v3/user/%40alice%3Alocalhost/account_data/m.direct")
    check global.ok
    check global.userId == "@alice:localhost"
    check global.roomId == ""
    check global.eventType == "m.direct"

    let room = userAccountDataPathParts("/_matrix/client/r0/user/%40alice%3Alocalhost/rooms/%21room%3Alocalhost/account_data/m.tag")
    check room.ok
    check room.roomId == "!room:localhost"
    check room.eventType == "m.tag"

    let deleted = userAccountDataPathParts("/_matrix/client/unstable/org.matrix.msc3391/user/%40alice%3Alocalhost/account_data/m.direct")
    check deleted.ok
    check deleted.eventType == "m.direct"

  test "account data is persisted and tombstones sync as deltas":
    let statePath = getTempDir() / "tuwunel-entrypoint-account-data.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    let first = state.setAccountDataLocked(
      "",
      "@alice:localhost",
      "m.direct",
      %*{"@bob:localhost": ["!room:localhost"]}
    )
    check first.streamPos == 1
    let fetched = state.getAccountDataLocked("", "@alice:localhost", "m.direct")
    check fetched.ok
    check fetched.content["@bob:localhost"][0].getStr("") == "!room:localhost"
    state.savePersistentState()

    let loaded = loadPersistentState(statePath)
    let loadedFetched = loaded.accountData[accountDataKey("", "@alice:localhost", "m.direct")]
    check loadedFetched.content["@bob:localhost"][0].getStr("") == "!room:localhost"

    discard state.setAccountDataLocked(
      "!room:localhost",
      "@alice:localhost",
      "m.tag",
      %*{"tags": {"u.work": {"order": 0.5}}}
    )
    check state.accountDataEventsForSync("@alice:localhost", "!room:localhost", 0, true).len == 1
    discard state.setAccountDataLocked("!room:localhost", "@alice:localhost", "m.tag", newJObject())
    let delta = state.accountDataEventsForSync("@alice:localhost", "!room:localhost", 2, false)
    check delta.len == 1
    check delta[0]["type"].getStr("") == "m.tag"
    check delta[0]["content"].kind == JObject
    check delta[0]["content"].len == 0
    check state.accountDataEventsForSync("@alice:localhost", "!room:localhost", 0, true).len == 0

  test "filters are persisted per user and filter id":
    let statePath = getTempDir() / "tuwunel-entrypoint-filters.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    state.filters[filterKey("@alice:localhost", "abcd")] = %*{
      "event_fields": ["type", "content.body"],
      "room": {"timeline": {"limit": 10}}
    }
    state.savePersistentState()

    let loaded = loadPersistentState(statePath)
    let filter = loaded.filters[filterKey("@alice:localhost", "abcd")]
    check filter["event_fields"][1].getStr("") == "content.body"
    check filter["room"]["timeline"]["limit"].getInt() == 10

  test "device path parsers cover collection, detail, and bulk delete":
    let collection = devicePathParts("/_matrix/client/v3/devices")
    check collection.ok
    check collection.collection
    let detail = devicePathParts("/_matrix/client/r0/devices/DEV%201")
    check detail.ok
    check not detail.collection
    check detail.deviceId == "DEV 1"
    check deleteDevicesPath("/_matrix/client/v3/delete_devices")

  test "device metadata follows token lifecycle and persists":
    let statePath = getTempDir() / "tuwunel-entrypoint-devices.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    let token = state.addTokenForUser("@alice:localhost", "DEV1", "Alice laptop")
    check token.len > 0
    let key = deviceKey("@alice:localhost", "DEV1")
    check key in state.devices
    check state.devices[key].displayName == "Alice laptop"
    check state.devices[key].lastSeenTs > 0

    discard state.upsertDeviceLocked("@alice:localhost", "DEV2", "Alice phone")
    let payload = state.listDevicesPayloadLocked("@alice:localhost")
    check payload["devices"].len == 2
    check payload["devices"][0]["device_id"].getStr("") == "DEV1"
    check payload["devices"][1]["device_id"].getStr("") == "DEV2"

    state.savePersistentState()
    let loaded = loadPersistentState(statePath)
    check loaded.devices[deviceKey("@alice:localhost", "DEV1")].displayName == "Alice laptop"

    state.removeDeviceLocked("@alice:localhost", "DEV1")
    check key notin state.devices
    check token notin state.tokens

  test "appservice delivery uses bearer auth instead of query token":
    let delivery = AppserviceDelivery(
      registrationId: "whatsapp",
      registrationUrl: "http://127.0.0.1:29336",
      hsToken: "hs-secret",
      txnId: "t123",
      payload: %*{"events": []},
      attempt: 0
    )

    let url = appserviceDeliveryUrl(delivery)
    let headers = appserviceDeliveryHeaders(delivery)

    check url == "http://127.0.0.1:29336/_matrix/app/v1/transactions/t123"
    check "access_token=" notin url
    check headers.hasKey("Authorization")
    check headers["Authorization"] == "Bearer hs-secret"
    check headers["Content-Type"] == "application/json"

  test "appservice delivery payload includes top-level redacts":
    let statePath = getTempDir() / "tuwunel-entrypoint-redact-delivery.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    state.rooms["!room:localhost"] = RoomData(
      roomId: "!room:localhost",
      creator: "@creator:localhost",
      isDirect: true,
      members: {
        "@creator:localhost": "join",
        "@whatsapp_46707749265:localhost": "join"
      }.toTable,
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )
    state.appserviceRegs = @[
      AppserviceRegistration(
        id: "whatsapp",
        url: "http://127.0.0.1:29336",
        asToken: "as-secret",
        hsToken: "hs-secret",
        senderLocalpart: "whatsappbot",
        userRegexes: @["^@whatsapp_.*:localhost$"],
        aliasRegexes: @[]
      )
    ]

    let ev = state.appendEventLocked(
      "!room:localhost",
      "@creator:localhost",
      "m.room.redaction",
      "",
      %*{"reason": "Removed in Beenim", "redacts": "$target"},
      redacts = "$target"
    )
    state.enqueueEventDeliveries(ev)

    check state.pendingDeliveries.len == 1
    let delivered = state.pendingDeliveries[0].payload["events"][0]
    check delivered["type"].getStr("") == "m.room.redaction"
    check delivered["redacts"].getStr("") == "$target"

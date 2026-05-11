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
    pushers: initTable[string, JsonNode](),
    pushRules: initTable[string, JsonNode](),
    typing: initTable[string, TypingRecord](),
    typingUpdates: initTable[string, int64](),
    receipts: initTable[string, ReceiptRecord](),
    presence: initTable[string, PresenceRecord](),
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
      avatarUrl: "mxc://localhost/alice",
      blurhash: "",
      timezone: "",
      profileFields: initTable[string, JsonNode]()
    )
    state.users["@bob:localhost"] = UserProfile(
      userId: "@bob:localhost",
      username: "bob",
      password: "",
      displayName: "Bob",
      avatarUrl: "",
      blurhash: "",
      timezone: "",
      profileFields: initTable[string, JsonNode]()
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

  test "room event path parser covers event and context routes":
    let eventRoute = roomAndEventFromPath("/_matrix/client/v3/rooms/%21room%3Alocalhost/event/%24evt%2F1", "event")
    check eventRoute.roomId == "!room:localhost"
    check eventRoute.eventId == "$evt/1"

    let contextRoute = roomAndEventFromPath("/_matrix/client/r0/rooms/%21room%3Alocalhost/context/%24evt2", "context")
    check contextRoute.roomId == "!room:localhost"
    check contextRoute.eventId == "$evt2"

    let wrongMarker = roomAndEventFromPath("/_matrix/client/v3/rooms/%21room%3Alocalhost/context/%24evt2", "event")
    check wrongMarker.roomId == ""
    check wrongMarker.eventId == ""

  test "room history helpers expose aliases context members and state-keyed events":
    let statePath = getTempDir() / "tuwunel-entrypoint-room-history.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    state.rooms["!room:localhost"] = RoomData(
      roomId: "!room:localhost",
      creator: "@alice:localhost",
      isDirect: true,
      members: initTable[string, string](),
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )

    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.member", "@alice:localhost", membershipContent("join"))
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.member", "@bob:localhost", membershipContent("leave"))
    let aliasEv = state.appendEventLocked(
      "!room:localhost",
      "@alice:localhost",
      "m.room.canonical_alias",
      "",
      %*{
        "alias": "#main:localhost",
        "alt_aliases": ["#side:localhost", "#main:localhost"]
      }
    )
    let msg1 = state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.message", "", %*{"msgtype": "m.text", "body": "one"})
    let msg2 = state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.message", "", %*{"msgtype": "m.text", "body": "two"})
    let msg3 = state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.message", "", %*{"msgtype": "m.text", "body": "three"})

    let room = state.rooms["!room:localhost"]
    check roomMembersArray(room, "join", "").len == 1
    check roomMembersArray(room, "", "leave").len == 1

    let aliases = roomAliasesPayload(room)
    check aliases["aliases"].len == 2
    check aliases["aliases"][0].getStr("") == "#main:localhost"
    check aliases["aliases"][1].getStr("") == "#side:localhost"

    let aliasJson = aliasEv.eventToJson()
    check aliasJson.hasKey("state_key")
    check aliasJson["state_key"].getStr("missing") == ""

    let idx = roomEventIndex(room, msg2.eventId)
    check idx >= 0
    check room.timeline[idx].eventToJson()["event_id"].getStr("") == msg2.eventId

    let context = roomContextPayload(room, idx, 3)
    check context["event"]["event_id"].getStr("") == msg2.eventId
    check context["events_before"].len == 1
    check context["events_before"][0]["event_id"].getStr("") == msg1.eventId
    check context["events_after"].len == 1
    check context["events_after"][0]["event_id"].getStr("") == msg3.eventId
    check context["state"].len >= 2

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

  test "tag path parsers cover stable client routes":
    let collection = userTagsPathParts("/_matrix/client/v3/user/%40alice%3Alocalhost/rooms/%21room%3Alocalhost/tags")
    check collection.ok
    check collection.collection
    check collection.userId == "@alice:localhost"
    check collection.roomId == "!room:localhost"

    let detail = userTagsPathParts("/_matrix/client/r0/user/%40alice%3Alocalhost/rooms/%21room%3Alocalhost/tags/u.work")
    check detail.ok
    check not detail.collection
    check detail.tag == "u.work"

  test "presence path parser covers stable client routes":
    let presence = presencePathParts("/_matrix/client/v3/presence/%40alice%3Alocalhost/status")
    check presence.ok
    check presence.userId == "@alice:localhost"

    let legacy = presencePathParts("/_matrix/client/r0/presence/%40bob%3Alocalhost/status")
    check legacy.ok
    check legacy.userId == "@bob:localhost"

  test "profile path parser covers stable and unstable field routes":
    let display = profilePathParts("/_matrix/client/v3/profile/%40alice%3Alocalhost/displayname")
    check display.userId == "@alice:localhost"
    check display.field == "displayname"

    let custom = profilePathParts("/_matrix/client/unstable/uk.tcpip.msc4133/profile/%40alice%3Alocalhost/com.example.status")
    check custom.userId == "@alice:localhost"
    check custom.field == "com.example.status"

    let timezone = profilePathParts("/_matrix/client/unstable/us.cloke.msc4175/profile/%40alice%3Alocalhost/m.tz")
    check timezone.userId == "@alice:localhost"
    check timezone.field == "m.tz"

  test "typing, receipt, and read-marker path parsers cover stable client routes":
    let typing = roomTypingPathParts("/_matrix/client/v3/rooms/%21room%3Alocalhost/typing/%40alice%3Alocalhost")
    check typing.ok
    check typing.roomId == "!room:localhost"
    check typing.userId == "@alice:localhost"

    let receipt = roomReceiptPathParts("/_matrix/client/r0/rooms/%21room%3Alocalhost/receipt/m.read/%24event")
    check receipt.ok
    check receipt.roomId == "!room:localhost"
    check receipt.receiptType == "m.read"
    check receipt.eventId == "$event"

    let readMarker = roomReadMarkersPathParts("/_matrix/client/v3/rooms/%21room%3Alocalhost/read_markers")
    check readMarker.ok
    check readMarker.roomId == "!room:localhost"

  test "typing state emits active and cleared ephemeral sync events":
    let statePath = getTempDir() / "tuwunel-entrypoint-typing.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    state.setTypingLocked("!room:localhost", "@alice:localhost", true, 30000)
    let initial = state.typingEventsForSync("!room:localhost", 0, true)
    check initial.len == 1
    check initial[0]["type"].getStr("") == "m.typing"
    check initial[0]["content"]["user_ids"][0].getStr("") == "@alice:localhost"

    let sinceActive = state.streamPos
    state.setTypingLocked("!room:localhost", "@alice:localhost", false, 30000)
    let cleared = state.typingEventsForSync("!room:localhost", sinceActive, false)
    check cleared.len == 1
    check cleared[0]["content"]["user_ids"].len == 0

  test "receipt records are grouped for sync and persisted":
    let statePath = getTempDir() / "tuwunel-entrypoint-receipts.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    discard state.setReceiptLocked("!room:localhost", "$event", "m.read", "@alice:localhost", "")
    discard state.setReceiptLocked("!room:localhost", "$event", "m.read.private", "@bob:localhost", "$thread")
    let ephemeral = state.receiptEventsForSync("!room:localhost", 0, true)
    check ephemeral.len == 1
    check ephemeral[0]["type"].getStr("") == "m.receipt"
    check ephemeral[0]["content"]["$event"]["m.read"]["@alice:localhost"]["ts"].getInt(0) > 0
    check ephemeral[0]["content"]["$event"]["m.read.private"]["@bob:localhost"]["thread_id"].getStr("") == "$thread"

    state.savePersistentState()
    let loaded = loadPersistentState(statePath)
    check loaded.receipts[receiptKey("!room:localhost", "$event", "m.read", "@alice:localhost", "")].userId == "@alice:localhost"

  test "presence records persist and sync only to users sharing rooms":
    let statePath = getTempDir() / "tuwunel-entrypoint-presence.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    state.users["@alice:localhost"] = UserProfile(
      userId: "@alice:localhost",
      username: "alice",
      password: "",
      displayName: "Alice",
      avatarUrl: "mxc://localhost/alice",
      blurhash: "",
      timezone: "",
      profileFields: initTable[string, JsonNode]()
    )
    state.rooms["!room:localhost"] = RoomData(
      roomId: "!room:localhost",
      creator: "@alice:localhost",
      isDirect: true,
      members: {
        "@alice:localhost": "join",
        "@bob:localhost": "join"
      }.toTable,
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )
    state.rebuildJoinedRooms()

    discard state.setPresenceLocked("@alice:localhost", "online", "available")
    let bobPresence = state.setPresenceLocked("@bob:localhost", "unavailable", "")
    discard state.setPresenceLocked("@carol:localhost", "online", "hidden")

    let response = presenceResponseJson(state.presence["@alice:localhost"])
    check response["presence"].getStr("") == "online"
    check response["currently_active"].getBool(false)
    check response["status_msg"].getStr("") == "available"

    let events = state.presenceEventsForSync("@alice:localhost", 0, true)
    check events.len == 2
    check events[0]["type"].getStr("") == "m.presence"
    check events[0]["sender"].getStr("") == "@alice:localhost"
    check events[0]["content"]["displayname"].getStr("") == "Alice"
    check events[1]["sender"].getStr("") == "@bob:localhost"

    let noDelta = state.presenceEventsForSync("@alice:localhost", bobPresence.streamPos, false)
    check noDelta.len == 0

    state.savePersistentState()
    let loaded = loadPersistentState(statePath)
    check loaded.presence["@alice:localhost"].presence == "online"
    check loaded.presence["@bob:localhost"].presence == "unavailable"

  test "profile fields include blurhash timezone custom keys and persistence":
    let statePath = getTempDir() / "tuwunel-entrypoint-profile-fields.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    var user = UserProfile(
      userId: "@alice:localhost",
      username: "alice",
      password: "",
      displayName: "Alice",
      avatarUrl: "mxc://localhost/avatar",
      blurhash: "LKO2?U%2Tw=w]~RBVZRi};RPxuwH",
      timezone: "Europe/Stockholm",
      profileFields: initTable[string, JsonNode]()
    )
    user.setUserProfileField("com.example.status", %*{"com.example.status": "coding"})
    state.users[user.userId] = user

    let profile = userProfilePayload(state.users[user.userId])
    check profile["displayname"].getStr("") == "Alice"
    check profile["avatar_url"].getStr("") == "mxc://localhost/avatar"
    check profile["blurhash"].getStr("") == "LKO2?U%2Tw=w]~RBVZRi};RPxuwH"
    check profile["m.tz"].getStr("") == "Europe/Stockholm"
    check profile["com.example.status"].getStr("") == "coding"

    let avatar = profileFieldPayload(state.users[user.userId], "avatar_url")
    check avatar.ok
    check avatar.payload["avatar_url"].getStr("") == "mxc://localhost/avatar"
    check avatar.payload["blurhash"].getStr("") == "LKO2?U%2Tw=w]~RBVZRi};RPxuwH"

    var editable = state.users[user.userId]
    editable.setUserProfileField("m.tz", %*{"m.tz": "UTC"})
    editable.deleteUserProfileField("com.example.status")
    state.users[user.userId] = editable
    check profileFieldPayload(state.users[user.userId], "m.tz").payload["m.tz"].getStr("") == "UTC"
    check not profileFieldPayload(state.users[user.userId], "com.example.status").ok

    state.savePersistentState()
    let loaded = loadPersistentState(statePath)
    check loaded.users[user.userId].timezone == "UTC"
    check loaded.users[user.userId].blurhash == "LKO2?U%2Tw=w]~RBVZRi};RPxuwH"

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

  test "tags are backed by m.tag account data and sync deltas":
    let statePath = getTempDir() / "tuwunel-entrypoint-tags.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    let first = state.setRoomTagLocked(
      "!room:localhost",
      "@alice:localhost",
      "u.work",
      %*{"order": 0.25}
    )
    check first.eventType == "m.tag"
    let tags = state.roomTagsContentLocked("!room:localhost", "@alice:localhost")
    check tags["tags"]["u.work"]["order"].getFloat() == 0.25

    state.savePersistentState()
    let loaded = loadPersistentState(statePath)
    let loadedTag = loaded.accountData[accountDataKey("!room:localhost", "@alice:localhost", "m.tag")]
    check loadedTag.content["tags"]["u.work"]["order"].getFloat() == 0.25

    discard state.deleteRoomTagLocked("!room:localhost", "@alice:localhost", "u.work")
    let delta = state.accountDataEventsForSync("@alice:localhost", "!room:localhost", first.streamPos, false)
    check delta.len == 1
    check delta[0]["type"].getStr("") == "m.tag"
    check delta[0]["content"]["tags"].len == 0

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

  test "client compatibility path parsers cover remaining local route families":
    check isJoinedRoomsPath("/_matrix/client/v3/joined_rooms")
    check isThirdPartyProtocolsPath("/_matrix/client/v3/thirdparty/protocols")
    check isTurnServerPath("/_matrix/client/v3/voip/turnServer")
    check isNotificationsPath("/_matrix/client/v3/notifications")
    check isPushersPath("/_matrix/client/v3/pushers")
    check isPushersSetPath("/_matrix/client/v3/pushers/set")
    check isPushRulesPath("/_matrix/client/v3/pushrules/global")
    let pushRule = pushRulePathParts("/_matrix/client/v3/pushrules/global/content/.m.rule.contains_user_name/enabled")
    check pushRule.ok
    check pushRule.scope == "global"
    check pushRule.kind == "content"
    check pushRule.ruleId == ".m.rule.contains_user_name"
    check pushRule.attr == "enabled"
    check isKeysUploadPath("/_matrix/client/v3/keys/upload")
    check isKeysQueryPath("/_matrix/client/v3/keys/query")
    check isKeysClaimPath("/_matrix/client/v3/keys/claim")
    check isKeysChangesPath("/_matrix/client/v3/keys/changes?from=s1&to=s2")
    check isSigningKeyUploadPath("/_matrix/client/v3/keys/device_signing/upload")
    check isSearchPath("/_matrix/client/v3/search")
    check isUserDirectorySearchPath("/_matrix/client/v3/user_directory/search")
    check roomKeysPathKind("/_matrix/client/v3/room_keys/version") == "version"
    check roomKeysPathKind("/_matrix/client/v3/room_keys/keys/%21room%3Alocalhost") == "keys"
    check isDehydratedDevicePath("/_matrix/client/unstable/org.matrix.msc2697.v2/dehydrated_device")

    let openId = openIdPathParts("/_matrix/client/v3/user/%40alice%3Alocalhost/openid/request_token")
    check openId.ok
    check openId.userId == "@alice:localhost"

    let toDevice = sendToDevicePathParts("/_matrix/client/v3/sendToDevice/m.room.encrypted/txn1")
    check toDevice.ok
    check toDevice.eventType == "m.room.encrypted"
    check toDevice.txnId == "txn1"

    let alias = directoryAliasPathParts("/_matrix/client/v3/directory/room/%23room%3Alocalhost")
    check alias.ok
    check alias.alias == "#room:localhost"

    let visibility = roomVisibilityPathParts("/_matrix/client/v3/directory/list/room/%21room%3Alocalhost")
    check visibility.ok
    check visibility.roomId == "!room:localhost"

    let reportEvent = reportPathParts("/_matrix/client/v3/rooms/%21room%3Alocalhost/report/%24event")
    check reportEvent.ok
    check reportEvent.roomId == "!room:localhost"
    check reportEvent.eventId == "$event"

    check knockTargetFromPath("/_matrix/client/v3/knock/%21room%3Alocalhost") == "!room:localhost"
    check roomInitialSyncId("/_matrix/client/v3/rooms/%21room%3Alocalhost/initialSync") == "!room:localhost"
    check unstableSummaryRoomId("/_matrix/client/unstable/im.nheko.summary/rooms/%21room%3Alocalhost/summary") == "!room:localhost"
    check relationRoomId("/_matrix/client/v3/rooms/%21room%3Alocalhost/relations/%24event/m.annotation") == "!room:localhost"
    check threadsRoomId("/_matrix/client/v3/rooms/%21room%3Alocalhost/threads") == "!room:localhost"
    check hierarchyRoomId("/_matrix/client/v3/rooms/%21space%3Alocalhost/hierarchy") == "!space:localhost"
    check upgradeRoomId("/_matrix/client/v3/rooms/%21room%3Alocalhost/upgrade") == "!room:localhost"
    check mutualRoomsUserId("/_matrix/client/v3/user/%40bob%3Alocalhost/mutual_rooms") == "@bob:localhost"

  test "client compatibility payloads return Matrix-shaped empty or local state":
    let statePath = getTempDir() / "tuwunel-entrypoint-client-compat-payloads.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    state.users["@alice:localhost"] = UserProfile(
      userId: "@alice:localhost",
      username: "alice",
      password: "",
      displayName: "Alice",
      avatarUrl: "mxc://localhost/alice",
      blurhash: "",
      timezone: "",
      profileFields: initTable[string, JsonNode]()
    )
    discard state.upsertDeviceLocked("@alice:localhost", "DEV1", "Alice laptop")
    state.rooms["!room:localhost"] = RoomData(
      roomId: "!room:localhost",
      creator: "@alice:localhost",
      isDirect: false,
      members: {"@alice:localhost": "join"}.toTable,
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.name", "", %*{"name": "Lobby"})

    let publicRooms = publicRoomsPayload(state)
    check publicRooms["chunk"].len == 1
    check publicRooms["chunk"][0]["room_id"].getStr("") == "!room:localhost"
    check publicRooms["chunk"][0]["name"].getStr("") == "Lobby"

    let directory = userDirectorySearchPayload(state, %*{"search_term": "ali", "limit": 5})
    check directory["results"].len == 1
    check directory["results"][0]["user_id"].getStr("") == "@alice:localhost"

    let keyQuery = keysQueryPayload(state, %*{"device_keys": {"@alice:localhost": ["DEV1"]}})
    check keyQuery["device_keys"]["@alice:localhost"]["DEV1"]["user_id"].getStr("") == "@alice:localhost"
    check keyUploadCounts(%*{"one_time_keys": {"signed_curve25519:AAAA": {}, "signed_curve25519:BBBB": {}}})["signed_curve25519"].getInt() == 2

    let initial = roomInitialSyncPayload(state.rooms["!room:localhost"], 10)
    check initial["room_id"].getStr("") == "!room:localhost"
    check initial["state"].len >= 1

    let summary = roomSummaryPayload(state.rooms["!room:localhost"])
    check summary["name"].getStr("") == "Lobby"
    check summary["joined_member_count"].getInt() == 1

  test "pushers and push rules persist Matrix client appstate":
    let statePath = getTempDir() / "tuwunel-entrypoint-push-appstate.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    let pusherBody = %*{
      "kind": "http",
      "app_id": "com.example.beenim",
      "pushkey": "push-key-1",
      "app_display_name": "Beenim",
      "device_display_name": "Mac",
      "lang": "en",
      "data": {"url": "https://push.example/notify"}
    }
    let pusherResult = state.setPusherLocked("@alice:localhost", pusherBody)
    check pusherResult.ok
    let pusherPayload = state.listPushersPayload("@alice:localhost")
    check pusherPayload["pushers"].len == 1
    check pusherPayload["pushers"][0]["app_id"].getStr("") == "com.example.beenim"
    check pusherPayload["pushers"][0]["pushkey"].getStr("") == "push-key-1"

    let ruleResult = state.putPushRuleLocked(
      "@alice:localhost",
      "global",
      "content",
      ".m.rule.contains_display_name",
      %*{"pattern": "Alice", "actions": ["notify"]},
    )
    check ruleResult.ok
    let enabledResult = state.updatePushRuleAttrLocked(
      "@alice:localhost",
      "global",
      "content",
      ".m.rule.contains_display_name",
      "enabled",
      %*{"enabled": false},
    )
    check enabledResult.ok
    let actionsResult = state.updatePushRuleAttrLocked(
      "@alice:localhost",
      "global",
      "content",
      ".m.rule.contains_display_name",
      "actions",
      %*{"actions": ["dont_notify"]},
    )
    check actionsResult.ok

    let rule = state.getPushRuleLocked(
      "@alice:localhost",
      "global",
      "content",
      ".m.rule.contains_display_name",
    )
    check rule.isSome
    check not rule.get["enabled"].getBool(true)
    check rule.get["actions"][0].getStr("") == "dont_notify"
    let allRules = state.pushRulesPayload("@alice:localhost")
    check allRules["global"]["content"].len == 1

    state.savePersistentState()
    let loaded = loadPersistentState(statePath)
    check loaded.pushers.len == 1
    check loaded.pushRules.len == 1
    check loaded.pushRules[
      pushRuleKey("@alice:localhost", "global", "content", ".m.rule.contains_display_name")
    ]["pattern"].getStr("") == "Alice"

    let deleteResult = state.setPusherLocked("@alice:localhost", %*{
      "kind": nil,
      "app_id": "com.example.beenim",
      "pushkey": "push-key-1"
    })
    check deleteResult.ok
    check state.listPushersPayload("@alice:localhost")["pushers"].len == 0

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

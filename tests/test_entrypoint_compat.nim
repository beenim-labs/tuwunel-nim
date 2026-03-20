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
    rooms: initTable[string, RoomData](),
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

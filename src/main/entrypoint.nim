import std/[algorithm, asynchttpserver, asyncdispatch, httpclient, json, locks, options, os, random, re, sets, strformat, strutils, tables, times, uri]
import main/args
import core/logging
import core/config_loader
import core/config_values

proc boolEnv(name: string; defaultValue = false): bool =
  let raw = getEnv(name)
  if raw.len == 0:
    return defaultValue
  case raw.toLowerAscii()
  of "1", "true", "yes", "on":
    true
  of "0", "false", "no", "off":
    false
  else:
    defaultValue

proc getConfigValue(cfg: FlatConfig; keys: openArray[string]): ConfigValue =
  for key in keys:
    if key in cfg:
      return cfg[key]
  newNullValue()

proc getConfigString(cfg: FlatConfig; keys: openArray[string]; fallback: string): string =
  let value = getConfigValue(cfg, keys)
  case value.kind
  of cvString:
    value.s
  of cvInt:
    $value.i
  of cvFloat:
    $value.f
  of cvBool:
    if value.b: "true" else: "false"
  else:
    fallback

proc getConfigInt(cfg: FlatConfig; keys: openArray[string]; fallback: int): int =
  let value = getConfigValue(cfg, keys)
  case value.kind
  of cvInt:
    int(value.i)
  of cvFloat:
    int(value.f)
  of cvString:
    try:
      parseInt(value.s)
    except ValueError:
      fallback
  else:
    fallback

proc getConfigBool(cfg: FlatConfig; keys: openArray[string]; fallback: bool): bool =
  let value = getConfigValue(cfg, keys)
  case value.kind
  of cvBool:
    value.b
  of cvString:
    case value.s.toLowerAscii()
    of "1", "true", "yes", "on":
      true
    of "0", "false", "no", "off":
      false
    else:
      fallback
  else:
    fallback

const
  RustBaselineVersion = "1.4.9"
  FallbackGifUrls = [
    "https://media.giphy.com/media/ICOgUNjpvO0PC/giphy.gif",
    "https://media.giphy.com/media/3o6ZtaO9BZHcOjmErm/giphy.gif",
    "https://media.giphy.com/media/xT0xeJpnrWC4XWblEk/giphy.gif",
    "https://media.giphy.com/media/l0HlBO7eyXzSZkJri/giphy.gif",
    "https://media.giphy.com/media/3o7TKtnuHOHHUjR38Y/giphy.gif",
    "https://media.giphy.com/media/26ufdipQqU2lhNA4g/giphy.gif",
    "https://media.giphy.com/media/3oriO0OEd9QIDdllqo/giphy.gif",
    "https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/giphy.gif",
    "https://media.giphy.com/media/5VKbvrjxpVJCM/giphy.gif",
    "https://media.giphy.com/media/13CoXDiaCcCoyk/giphy.gif",
    "https://media.giphy.com/media/26BRuo6sLetdllPAQ/giphy.gif",
    "https://media.giphy.com/media/3o6fJ1BM7R2EBRDnxK/giphy.gif"
  ]

proc versionsResponse(): JsonNode =
  %*{
    "versions": [
      "r0.0.1",
      "r0.1.0",
      "r0.2.0",
      "r0.3.0",
      "r0.4.0",
      "r0.5.0",
      "r0.6.0",
      "r0.6.1",
      "v1.1",
      "v1.2",
      "v1.3",
      "v1.4",
      "v1.5",
      "v1.10",
      "v1.11"
    ],
    "unstable_features": {
      "fi.mau.msc2659.stable": true,
      "fi.mau.msc2815": true,
      "org.matrix.e2e_cross_signing": true,
      "org.matrix.msc2285.stable": true,
      "org.matrix.msc2836": true,
      "org.matrix.msc2946": true
    }
  }

proc isAppservicePingPath(path: string): bool =
  path.startsWith("/_matrix/client/v1/appservice/") and path.endsWith("/ping")

proc extractAppservicePingRegistrationId(path: string): string =
  const Prefix = "/_matrix/client/v1/appservice/"
  const Suffix = "/ping"
  if not isAppservicePingPath(path):
    return ""
  let startIdx = Prefix.len
  let endIdx = path.len - Suffix.len
  if endIdx <= startIdx:
    return ""
  let raw = path[startIdx ..< endIdx]
  if raw.len == 0 or '/' in raw:
    return ""
  decodeUrl(raw)

proc loginTypesResponse(): JsonNode =
  %*{
    "flows": [
      {"type": "m.login.application_service"},
      {"type": "org.matrix.login.jwt"},
      {"type": "m.login.password"},
      {"type": "m.login.token", "get_login_token": true}
    ]
  }

proc matrixError(errcode, message: string): JsonNode =
  %*{
    "errcode": errcode,
    "error": errcode & ": " & message
  }

proc respondJson(req: Request; code: HttpCode; payload: JsonNode) {.async.} =
  let headers = newHttpHeaders({
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
  })
  await req.respond(code, $payload, headers)

proc respondRaw(
    req: Request;
    code: HttpCode;
    body: string;
    contentType = "application/octet-stream";
    cacheControl = "no-store"
) {.async.} =
  let headers = newHttpHeaders({
    "Content-Type": contentType,
    "Cache-Control": cacheControl,
  })
  await req.respond(code, body, headers)

proc hasAccessToken(req: Request): bool =
  if req.headers.hasKey("Authorization"):
    let auth = req.headers["Authorization"].strip()
    if auth.len > "Bearer ".len and auth.toLowerAscii().startsWith("bearer "):
      return true
  if req.url.query.len > 0 and req.url.query.contains("access_token="):
    return true
  false

proc hasFederationAuth(req: Request): bool =
  if not req.headers.hasKey("Authorization"):
    return false
  req.headers["Authorization"].strip().toLowerAscii().startsWith("x-matrix")

proc resolveRouteName(path: string): string =
  case path
  of "/_matrix/client/v3/account/whoami", "/_matrix/client/r0/account/whoami":
    return "whoami_route"
  of "/_matrix/client/v3/login", "/_matrix/client/r0/login":
    return "login_route"
  of "/_matrix/client/v3/register", "/_matrix/client/r0/register":
    return "register_route"
  of "/_matrix/client/v3/logout", "/_matrix/client/r0/logout":
    return "logout_route"
  of "/_matrix/client/v3/logout/all", "/_matrix/client/r0/logout/all":
    return "logout_all_route"
  of "/_matrix/client/v3/capabilities", "/_matrix/client/r0/capabilities":
    return "get_capabilities_route"
  of "/_matrix/client/v3/sync", "/_matrix/client/r0/sync":
    return "sync_events_route"
  of "/_matrix/key/v2/server":
    return "/_matrix/key/v2/server"
  of "/client/server.json":
    return "/client/server.json"
  of "/_tuwunel/server_version":
    return "/_tuwunel/server_version"
  of "/.well-known/matrix/server":
    return "/.well-known/matrix/server"
  else:
    discard

  if path.startsWith("/_matrix/key/v2/server/"):
    return "/_matrix/key/v2/server/{key_id}"
  if path.startsWith("/_matrix/federation/"):
    return "/_matrix/federation/{*path}"
  if path.startsWith("/_matrix/key/"):
    return "/_matrix/key/{*path}"
  if path.startsWith("/_matrix/media/v1/"):
    return "/_matrix/media/v1/{*path}"
  if path.startsWith("/_matrix/media/v3/download/"):
    return "/_matrix/media/v3/download/{*path}"
  if path.startsWith("/_matrix/media/v3/thumbnail/"):
    return "/_matrix/media/v3/thumbnail/{*path}"
  if path.startsWith("/_matrix/media/r0/download/"):
    return "/_matrix/media/r0/download/{*path}"
  if path.startsWith("/_matrix/media/r0/thumbnail/"):
    return "/_matrix/media/r0/thumbnail/{*path}"
  ""

proc routeNeedsAccessToken(routeName: string): bool =
  case routeName
  of "whoami_route", "logout_route", "logout_all_route", "get_capabilities_route", "sync_events_route",
      "/_matrix/media/v1/{*path}":
    true
  else:
    false

proc isSyncPath(path: string): bool =
  path == "/_matrix/client/v3/sync" or path == "/_matrix/client/r0/sync"

proc queryParam(req: Request; key: string): string =
  let query = req.url.query
  if query.len == 0:
    return ""

  for rawPair in query.split('&'):
    if rawPair.len == 0:
      continue
    let sep = rawPair.find('=')
    let rawKey = if sep >= 0: rawPair[0..<sep] else: rawPair
    let rawVal = if sep >= 0 and sep + 1 < rawPair.len: rawPair[(sep + 1)..^1] else: ""

    var decodedKey = rawKey
    try:
      decodedKey = decodeUrl(rawKey, decodePlus = true)
    except CatchableError:
      discard

    if decodedKey != key:
      continue

    try:
      return decodeUrl(rawVal, decodePlus = true)
    except CatchableError:
      return rawVal

  ""

proc nextSyncBatchToken(sinceToken: string): string =
  if sinceToken.len > 1 and sinceToken[0] == 's':
    try:
      let nextValue = parseInt(sinceToken[1..^1]) + 1
      return "s" & $nextValue
    except ValueError:
      discard
  "s1"

proc clampInt(value: int; minValue: int; maxValue: int): int =
  result = value
  if result < minValue:
    result = minValue
  if result > maxValue:
    result = maxValue

proc extractUrlHost(rawUrl: string): string =
  let trimmed = rawUrl.strip().toLowerAscii()
  let sep = trimmed.find("://")
  if sep < 0:
    return ""
  var authority = trimmed[(sep + 3) .. ^1]
  let slash = authority.find('/')
  if slash >= 0:
    authority = authority[0 ..< slash]
  let atPos = authority.rfind('@')
  if atPos >= 0 and atPos + 1 < authority.len:
    authority = authority[(atPos + 1) .. ^1]
  if authority.startsWith("["):
    let closing = authority.find(']')
    if closing > 1:
      return authority[1 ..< closing]
  let colon = authority.rfind(':')
  if colon > 0 and authority.count(':') == 1:
    authority = authority[0 ..< colon]
  authority

proc isAllowedGifProxyUrl(rawUrl: string): bool =
  if not (rawUrl.startsWith("https://") or rawUrl.startsWith("http://")):
    return false
  let host = extractUrlHost(rawUrl)
  if host.len == 0:
    return false
  host == "giphy.com" or host.endsWith(".giphy.com")

proc giphyHttpFallbackUrl(rawUrl: string): string =
  ## Nim/OpenSSL in this environment fails TLS handshakes to media*.giphy.com.
  ## Retry those URLs over HTTP to keep GIF previews working through the proxy.
  if not rawUrl.startsWith("https://"):
    return ""
  let host = extractUrlHost(rawUrl)
  if host.len == 0:
    return ""
  if host == "giphy.com" or host.endsWith(".giphy.com"):
    return "http://" & rawUrl[8 .. ^1]
  ""

proc requestBaseUrl(req: Request; bindAddress: string; bindPort: int): string =
  var scheme = "http"
  if req.headers.hasKey("X-Forwarded-Proto"):
    let forwarded = req.headers["X-Forwarded-Proto"].split(",")[0].strip().toLowerAscii()
    if forwarded == "http" or forwarded == "https":
      scheme = forwarded
  var host = req.headers.getOrDefault("Host").strip()
  if host.len == 0:
    host = bindAddress
    if not host.contains(":"):
      host &= ":" & $bindPort
  scheme & "://" & host

proc nestedJsonString(node: JsonNode; keys: openArray[string]): string =
  var cur = node
  for key in keys:
    if cur.kind != JObject or not cur.hasKey(key):
      return ""
    cur = cur[key]
  if cur.kind == JString:
    cur.getStr("")
  else:
    ""

proc mapGiphyPayload(upstream: JsonNode; baseUrl: string): JsonNode =
  var gifs = newJArray()
  let data = upstream.getOrDefault("data")
  if data.kind == JArray:
    for item in data:
      if item.kind != JObject:
        continue

      var previewUrl = nestedJsonString(item, ["images", "preview_gif", "url"])
      if previewUrl.len == 0:
        previewUrl = nestedJsonString(item, ["images", "fixed_width_small", "url"])
      if previewUrl.len == 0:
        previewUrl = nestedJsonString(item, ["images", "fixed_width", "url"])
      if previewUrl.len == 0:
        previewUrl = nestedJsonString(item, ["images", "original", "url"])

      var sendUrl = nestedJsonString(item, ["images", "original", "url"])
      if sendUrl.len == 0:
        sendUrl = nestedJsonString(item, ["images", "downsized_large", "url"])
      if sendUrl.len == 0:
        let gifId = item.getOrDefault("id").getStr("")
        if gifId.len > 0:
          sendUrl = "https://media.giphy.com/media/" & encodeUrl(gifId) & "/giphy.gif"

      if previewUrl.len == 0 or sendUrl.len == 0:
        continue
      if not isAllowedGifProxyUrl(previewUrl) or not isAllowedGifProxyUrl(sendUrl):
        continue

      let proxyPreview = baseUrl & "/_beenim/gifs/media?u=" & encodeUrl(previewUrl)
      gifs.add(%*{
        "id": item.getOrDefault("id").getStr(""),
        "preview_url": proxyPreview,
        "send_url": sendUrl
      })

  %*{"gifs": gifs}

proc fallbackGifPayload(baseUrl: string): JsonNode =
  var gifs = newJArray()
  var idx = 0
  for url in FallbackGifUrls:
    if not isAllowedGifProxyUrl(url):
      continue
    inc idx
    gifs.add(%*{
      "id": "fallback_" & $idx,
      "preview_url": baseUrl & "/_beenim/gifs/media?u=" & encodeUrl(url),
      "send_url": url
    })
  %*{"gifs": gifs}

type
  AccessSession = object
    userId: string
    deviceId: string
    issuedAtMs: int64
    isAppservice: bool
    appserviceId: string

  UserProfile = object
    userId: string
    username: string
    password: string
    displayName: string
    avatarUrl: string

  MatrixEventRecord = object
    streamPos: int64
    eventId: string
    roomId: string
    sender: string
    eventType: string
    stateKey: string
    redacts: string
    originServerTs: int64
    content: JsonNode

  RoomData = object
    roomId: string
    creator: string
    isDirect: bool
    members: Table[string, string]
    timeline: seq[MatrixEventRecord]
    stateByKey: Table[string, MatrixEventRecord]

  AppserviceRegistration = object
    id: string
    url: string
    asToken: string
    hsToken: string
    senderLocalpart: string
    userRegexes: seq[string]
    aliasRegexes: seq[string]

  AppserviceDelivery = object
    registrationId: string
    registrationUrl: string
    hsToken: string
    txnId: string
    payload: JsonNode
    attempt: int

  AppserviceDeliveryResult = object
    ok: bool
    statusCode: int
    responseBody: string
    errorMessage: string

  ServerState = ref object
    lock: Lock
    statePath: string
    serverName: string
    streamPos: int64
    deliveryCounter: int64
    roomCounter: int64
    usersByName: Table[string, string]
    users: Table[string, UserProfile]
    tokens: Table[string, AccessSession]
    userTokens: Table[string, seq[string]]
    rooms: Table[string, RoomData]
    userJoinedRooms: Table[string, HashSet[string]]
    appserviceRegs: seq[AppserviceRegistration]
    appserviceByAsToken: Table[string, AppserviceRegistration]
    pendingDeliveries: seq[AppserviceDelivery]
    deliveryInFlight: int
    deliveryBaseMs: int
    deliveryMaxMs: int
    deliveryMaxAttempts: int
    deliveryMaxInflight: int
    deliverySent: int64
    deliveryFailed: int64
    deliveryDeadLetters: int64

proc nowMs(): int64 =
  getTime().toUnix().int64 * 1000

var seededRandom = false

proc ensureRandomSeeded() =
  if not seededRandom:
    randomize()
    seededRandom = true

proc randomString(prefix: string; n = 32): string =
  ensureRandomSeeded()
  const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  result = prefix
  for _ in 0 ..< n:
    result.add(chars[rand(chars.high)])

proc stateKey(eventType, stateKey: string): string =
  eventType & "\x1f" & stateKey

proc isStateEventForStorage(eventType, stateKeyValue: string): bool

proc trimQuotes(raw: string): string =
  result = raw.strip()
  if result.len >= 2 and ((result[0] == '"' and result[^1] == '"') or (result[0] == '\'' and result[^1] == '\'')):
    result = result[1 .. ^2]

proc localpartFromUserId(userId: string): string =
  if userId.len < 4 or userId[0] != '@':
    return ""
  let sep = userId.find(':')
  if sep <= 1:
    return ""
  userId[1 ..< sep]

proc parseSinceToken(sinceToken: string): int64 =
  if sinceToken.len <= 1 or sinceToken[0] != 's':
    return 0
  try:
    parseInt(sinceToken[1 .. ^1]).int64
  except ValueError:
    0

proc encodeSinceToken(streamPos: int64): string =
  "s" & $streamPos

proc statePathFromConfig(cfg: FlatConfig): string =
  var path = getConfigString(cfg, ["state_path", "global.state_path"], "sdk/tuwunel-nim-state.json")
  if path.len == 0:
    path = "sdk/tuwunel-nim-state.json"
  path

proc mediaDirFromStatePath(statePath: string): string =
  joinPath(parentDir(statePath), "media")

proc mediaMetaPath(statePath: string, mediaId: string): string =
  joinPath(mediaDirFromStatePath(statePath), mediaId & ".meta.json")

proc mediaDataPath(statePath: string, mediaId: string): string =
  joinPath(mediaDirFromStatePath(statePath), mediaId & ".bin")

proc storeUploadedMedia(
    state: ServerState,
    body: string,
    contentType: string,
    fileName: string
): string =
  let mediaId = randomString("media_", 24)
  let mediaDir = mediaDirFromStatePath(state.statePath)
  createDir(mediaDir)
  writeFile(mediaDataPath(state.statePath, mediaId), body)
  writeFile(
    mediaMetaPath(state.statePath, mediaId),
    $(%*{
      "content_type": contentType,
      "file_name": fileName
    })
  )
  mediaId

proc loadStoredMediaMeta(
    state: ServerState,
    mediaId: string
): tuple[ok: bool, contentType: string, fileName: string] =
  let metaPath = mediaMetaPath(state.statePath, mediaId)
  if not fileExists(metaPath):
    return (false, "application/octet-stream", "")
  try:
    let parsed = parseFile(metaPath)
    (
      true,
      parsed{"content_type"}.getStr("application/octet-stream"),
      parsed{"file_name"}.getStr("")
    )
  except CatchableError:
    (false, "application/octet-stream", "")

proc getConfigStringArray(cfg: FlatConfig; key: string): seq[string] =
  result = @[]
  if key notin cfg:
    return
  let v = cfg[key]
  case v.kind
  of cvArray:
    for item in v.items:
      case item.kind
      of cvString:
        result.add(item.s)
      of cvInt:
        result.add($item.i)
      of cvFloat:
        result.add($item.f)
      of cvBool:
        result.add(if item.b: "true" else: "false")
      else:
        discard
  of cvString:
    result.add(v.s)
  else:
    discard

proc getConfigStringArray(cfg: FlatConfig; keys: openArray[string]): seq[string] =
  result = @[]
  for key in keys:
    result.add(getConfigStringArray(cfg, key))

proc eventToJson(ev: MatrixEventRecord): JsonNode =
  result = %*{
    "event_id": ev.eventId,
    "room_id": ev.roomId,
    "sender": ev.sender,
    "type": ev.eventType,
    "origin_server_ts": ev.originServerTs,
    "content": ev.content,
  }
  if ev.stateKey.len > 0:
    result["state_key"] = %ev.stateKey
  if ev.redacts.len > 0:
    result["redacts"] = %ev.redacts

proc toPersistentJson(state: ServerState): JsonNode =
  var root = newJObject()
  root["stream_pos"] = %state.streamPos
  root["delivery_counter"] = %state.deliveryCounter
  root["room_counter"] = %state.roomCounter

  var users = newJArray()
  for _, user in state.users:
    users.add(%*{
      "user_id": user.userId,
      "username": user.username,
      "password": user.password,
      "display_name": user.displayName,
      "avatar_url": user.avatarUrl
    })
  root["users"] = users

  var tokens = newJArray()
  for token, sess in state.tokens:
    if sess.isAppservice:
      continue
    tokens.add(%*{
      "token": token,
      "user_id": sess.userId,
      "device_id": sess.deviceId,
      "issued_at_ms": sess.issuedAtMs
    })
  root["tokens"] = tokens

  var rooms = newJArray()
  for _, room in state.rooms:
    var members = newJObject()
    for memberId, membership in room.members:
      members[memberId] = %membership

    var timeline = newJArray()
    for ev in room.timeline:
      timeline.add(%*{
        "stream_pos": ev.streamPos,
        "event_id": ev.eventId,
        "room_id": ev.roomId,
        "sender": ev.sender,
        "type": ev.eventType,
        "state_key": ev.stateKey,
        "redacts": ev.redacts,
        "origin_server_ts": ev.originServerTs,
        "content": ev.content
      })

    rooms.add(%*{
      "room_id": room.roomId,
      "creator": room.creator,
      "is_direct": room.isDirect,
      "members": members,
      "timeline": timeline
    })
  root["rooms"] = rooms
  root

proc rebuildJoinedRooms(state: ServerState) =
  state.userJoinedRooms.clear()
  for _, room in state.rooms:
    for userId, membership in room.members:
      if membership != "join":
        continue
      if userId notin state.userJoinedRooms:
        state.userJoinedRooms[userId] = initHashSet[string]()
      state.userJoinedRooms[userId].incl(room.roomId)

proc loadPersistentState(path: string): tuple[
    usersByName: Table[string, string],
    users: Table[string, UserProfile],
    tokens: Table[string, AccessSession],
    userTokens: Table[string, seq[string]],
    rooms: Table[string, RoomData],
    streamPos: int64,
    deliveryCounter: int64,
    roomCounter: int64
] =
  result = (
    usersByName: initTable[string, string](),
    users: initTable[string, UserProfile](),
    tokens: initTable[string, AccessSession](),
    userTokens: initTable[string, seq[string]](),
    rooms: initTable[string, RoomData](),
    streamPos: 0'i64,
    deliveryCounter: 0'i64,
    roomCounter: 0'i64
  )

  if not fileExists(path):
    return

  try:
    let root = parseFile(path)
    result.streamPos = root{"stream_pos"}.getInt(0).int64
    result.deliveryCounter = root{"delivery_counter"}.getInt(0).int64
    result.roomCounter = root{"room_counter"}.getInt(0).int64

    if root.hasKey("users") and root["users"].kind == JArray:
      for node in root["users"]:
        if node.kind != JObject:
          continue
        let userId = node{"user_id"}.getStr("")
        let username = node{"username"}.getStr("")
        if userId.len == 0:
          continue
        let user = UserProfile(
          userId: userId,
          username: username,
          password: node{"password"}.getStr(""),
          displayName: node{"display_name"}.getStr(""),
          avatarUrl: node{"avatar_url"}.getStr("")
        )
        result.users[userId] = user
        if username.len > 0:
          result.usersByName[username] = userId

    if root.hasKey("tokens") and root["tokens"].kind == JArray:
      for node in root["tokens"]:
        if node.kind != JObject:
          continue
        let token = node{"token"}.getStr("")
        let userId = node{"user_id"}.getStr("")
        if token.len == 0 or userId.len == 0:
          continue
        let session = AccessSession(
          userId: userId,
          deviceId: node{"device_id"}.getStr(""),
          issuedAtMs: node{"issued_at_ms"}.getInt(nowMs().int).int64,
          isAppservice: false,
          appserviceId: ""
        )
        result.tokens[token] = session
        if userId notin result.userTokens:
          result.userTokens[userId] = @[]
        result.userTokens[userId].add(token)

    if root.hasKey("rooms") and root["rooms"].kind == JArray:
      for roomNode in root["rooms"]:
        if roomNode.kind != JObject:
          continue
        let roomId = roomNode{"room_id"}.getStr("")
        if roomId.len == 0:
          continue

        var room = RoomData(
          roomId: roomId,
          creator: roomNode{"creator"}.getStr(""),
          isDirect: roomNode{"is_direct"}.getBool(false),
          members: initTable[string, string](),
          timeline: @[],
          stateByKey: initTable[string, MatrixEventRecord]()
        )

        if roomNode.hasKey("members") and roomNode["members"].kind == JObject:
          for userId, membershipNode in roomNode["members"]:
            room.members[userId] = membershipNode.getStr("")

        if roomNode.hasKey("timeline") and roomNode["timeline"].kind == JArray:
          for evNode in roomNode["timeline"]:
            if evNode.kind != JObject:
              continue
            let ev = MatrixEventRecord(
              streamPos: evNode{"stream_pos"}.getInt(0).int64,
              eventId: evNode{"event_id"}.getStr(""),
              roomId: evNode{"room_id"}.getStr(roomId),
              sender: evNode{"sender"}.getStr(""),
              eventType: evNode{"type"}.getStr(""),
              stateKey: evNode{"state_key"}.getStr(""),
              redacts:
                block:
                  let topLevel = evNode{"redacts"}.getStr("")
                  if topLevel.len > 0:
                    topLevel
                  else:
                    evNode{"content"}{"redacts"}.getStr(""),
              originServerTs: evNode{"origin_server_ts"}.getInt(0).int64,
              content: if evNode.hasKey("content"): evNode["content"] else: newJObject()
            )
            room.timeline.add(ev)
            if isStateEventForStorage(ev.eventType, ev.stateKey):
              room.stateByKey[stateKey(ev.eventType, ev.stateKey)] = ev
            if ev.streamPos > result.streamPos:
              result.streamPos = ev.streamPos
          room.timeline.sort(proc(a, b: MatrixEventRecord): int = cmp(a.streamPos, b.streamPos))

        result.rooms[roomId] = room
  except CatchableError as e:
    warn("Failed to load persisted native state: " & e.msg)

proc savePersistentState(state: ServerState) =
  try:
    let parent = parentDir(state.statePath)
    if parent.len > 0 and parent != ".":
      createDir(parent)
    writeFile(state.statePath, $state.toPersistentJson())
  except CatchableError as e:
    warn("Failed to persist native state: " & e.msg)

proc parseRegistrationYaml(content: string): Option[AppserviceRegistration] =
  var reg = AppserviceRegistration(
    id: "",
    url: "",
    asToken: "",
    hsToken: "",
    senderLocalpart: "",
    userRegexes: @[],
    aliasRegexes: @[]
  )

  var currentNamespace = ""
  for raw in content.splitLines():
    let line = raw.strip()
    if line.len == 0 or line.startsWith("#"):
      continue
    if line.startsWith("id:"):
      reg.id = trimQuotes(line.split(":", 1)[1])
    elif line.startsWith("url:"):
      reg.url = trimQuotes(line.split(":", 1)[1])
    elif line.startsWith("as_token:"):
      reg.asToken = trimQuotes(line.split(":", 1)[1])
    elif line.startsWith("hs_token:"):
      reg.hsToken = trimQuotes(line.split(":", 1)[1])
    elif line.startsWith("sender_localpart:"):
      reg.senderLocalpart = trimQuotes(line.split(":", 1)[1])
    elif line.startsWith("users:"):
      currentNamespace = "users"
    elif line.startsWith("aliases:"):
      currentNamespace = "aliases"
    elif line.startsWith("rooms:"):
      currentNamespace = "rooms"
    elif line.startsWith("- regex:") or line.startsWith("regex:"):
      let regexRaw = if ":" in line: trimQuotes(line.split(":", 1)[1]) else: ""
      if regexRaw.len == 0:
        continue
      if currentNamespace == "users":
        reg.userRegexes.add(regexRaw)
      elif currentNamespace == "aliases":
        reg.aliasRegexes.add(regexRaw)

  if reg.id.len == 0 or reg.url.len == 0 or reg.asToken.len == 0 or reg.hsToken.len == 0:
    return none(AppserviceRegistration)
  some(reg)

proc appservicePingResponseForRegs(
    registrations: openArray[AppserviceRegistration],
    registrationId: string,
    accessToken: string
): tuple[code: HttpCode, payload: JsonNode] =
  let normalizedId = registrationId.strip()
  if normalizedId.len == 0:
    return (Http404, matrixError("M_NOT_FOUND", "Unknown appservice."))

  var reg = AppserviceRegistration()
  var found = false
  for candidate in registrations:
    if candidate.id == normalizedId:
      reg = candidate
      found = true
      break
  if not found:
    return (Http404, matrixError("M_NOT_FOUND", "Unknown appservice."))

  let token = accessToken.strip()
  if token.len == 0:
    return (Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
  if token != reg.asToken:
    return (Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))

  (Http200, %*{"duration_ms": 0})

proc appservicePingTestResponse*(
    registrationYamls: seq[string],
    registrationId: string,
    accessToken: string
): tuple[status: int, payload: JsonNode] =
  var registrations: seq[AppserviceRegistration] = @[]
  for yamlSnippet in registrationYamls:
    let parsed = parseRegistrationYaml(yamlSnippet)
    if parsed.isSome:
      registrations.add(parsed.get())
  let response = appservicePingResponseForRegs(registrations, registrationId, accessToken)
  (response.code.int, response.payload)

proc extractEmbeddedYaml(adminEntry: string): seq[string] =
  result = @[]
  var cursor = 0
  while true:
    let start = adminEntry.find("```", cursor)
    if start < 0:
      break
    let dataStart = start + 3
    let endFence = adminEntry.find("```", dataStart)
    if endFence < 0:
      break
    let yamlBlock = adminEntry[dataStart ..< endFence].strip()
    if yamlBlock.len > 0:
      result.add(yamlBlock)
    cursor = endFence + 3

proc loadAppserviceRegistrations(cfg: FlatConfig): seq[AppserviceRegistration] =
  result = @[]
  var seen = initHashSet[string]()
  let regDir = getConfigString(cfg, ["appservice.registrations_dir", "global.appservice.registrations_dir"], "")
  if regDir.len > 0 and dirExists(regDir):
    for filePath in walkDirRec(regDir):
      let lower = filePath.toLowerAscii()
      if not (lower.endsWith(".yaml") or lower.endsWith(".yml")):
        continue
      try:
        let parsed = parseRegistrationYaml(readFile(filePath))
        if parsed.isSome:
          let reg = parsed.get()
          if reg.id notin seen:
            result.add(reg)
            seen.incl(reg.id)
      except CatchableError as e:
        warn("Failed to load appservice registration file " & filePath & ": " & e.msg)

  for adminEntry in getConfigStringArray(cfg, ["admin_execute", "global.admin_execute"]):
    for yamlSnippet in extractEmbeddedYaml(adminEntry):
      let parsed = parseRegistrationYaml(yamlSnippet)
      if parsed.isNone:
        continue
      let reg = parsed.get()
      if reg.id in seen:
        continue
      result.add(reg)
      seen.incl(reg.id)

proc userRegexMatches(reg: AppserviceRegistration; userId: string): bool =
  if reg.userRegexes.len == 0:
    return false
  for rawRegex in reg.userRegexes:
    try:
      if userId.match(re(rawRegex)):
        return true
    except CatchableError:
      discard
  false

proc resolveAppserviceSender(reg: AppserviceRegistration; serverName: string): string =
  let localpart = if reg.senderLocalpart.len > 0: reg.senderLocalpart else: reg.id & "bot"
  "@" & localpart & ":" & serverName

proc newServerState(cfg: FlatConfig; serverName: string): ServerState =
  let statePath = statePathFromConfig(cfg)
  let loaded = loadPersistentState(statePath)
  result = ServerState(
    statePath: statePath,
    serverName: serverName,
    streamPos: loaded.streamPos,
    deliveryCounter: loaded.deliveryCounter,
    roomCounter: loaded.roomCounter,
    usersByName: loaded.usersByName,
    users: loaded.users,
    tokens: loaded.tokens,
    userTokens: loaded.userTokens,
    rooms: loaded.rooms,
    userJoinedRooms: initTable[string, HashSet[string]](),
    appserviceRegs: loadAppserviceRegistrations(cfg),
    appserviceByAsToken: initTable[string, AppserviceRegistration](),
    pendingDeliveries: @[],
    deliveryInFlight: 0,
    deliveryBaseMs: max(100, getConfigInt(cfg, ["appservice.delivery.retry_base_ms", "global.appservice.delivery.retry_base_ms"], 1000)),
    deliveryMaxMs: max(500, getConfigInt(cfg, ["appservice.delivery.retry_max_ms", "global.appservice.delivery.retry_max_ms"], 30000)),
    deliveryMaxAttempts: max(1, getConfigInt(cfg, ["appservice.delivery.max_attempts", "global.appservice.delivery.max_attempts"], 6)),
    deliveryMaxInflight: max(1, getConfigInt(cfg, ["appservice.delivery.max_inflight", "global.appservice.delivery.max_inflight"], 4)),
    deliverySent: 0,
    deliveryFailed: 0,
    deliveryDeadLetters: 0
  )
  initLock(result.lock)
  result.rebuildJoinedRooms()

  for reg in result.appserviceRegs:
    result.appserviceByAsToken[reg.asToken] = reg
  info("Loaded appservice registrations: " & $result.appserviceRegs.len)

proc addTokenForUser(state: ServerState; userId, deviceId: string): string =
  let token = randomString("syt_", 48)
  let session = AccessSession(
    userId: userId,
    deviceId: deviceId,
    issuedAtMs: nowMs(),
    isAppservice: false,
    appserviceId: ""
  )
  state.tokens[token] = session
  if userId notin state.userTokens:
    state.userTokens[userId] = @[]
  state.userTokens[userId].add(token)
  token

proc removeToken(state: ServerState; token: string) =
  if token notin state.tokens:
    return
  let session = state.tokens[token]
  state.tokens.del(token)
  if session.userId in state.userTokens:
    var kept: seq[string] = @[]
    for existing in state.userTokens[session.userId]:
      if existing != token:
        kept.add(existing)
    if kept.len == 0:
      state.userTokens.del(session.userId)
    else:
      state.userTokens[session.userId] = kept

proc removeAllTokensForUser(state: ServerState; userId: string) =
  if userId notin state.userTokens:
    return
  for token in state.userTokens[userId]:
    if token in state.tokens:
      state.tokens.del(token)
  state.userTokens.del(userId)

proc membershipContent(status: string): JsonNode =
  %*{"membership": status}

proc appendEventLocked(
    state: ServerState;
    roomId, sender, eventType, stateKeyValue: string;
    content: JsonNode;
    redacts = ""
): MatrixEventRecord {.gcsafe.}

proc isStateEventForStorage(eventType, stateKeyValue: string): bool =
  if stateKeyValue.len > 0:
    return true
  eventType in [
    "m.room.create",
    "m.room.power_levels",
    "m.room.name",
    "m.room.topic",
    "m.room.avatar",
    "m.room.join_rules",
    "m.room.encryption",
    "m.room.history_visibility",
    "m.room.guest_access"
  ]

proc defaultPowerLevelsContent(ownerUserId: string): JsonNode =
  var users = newJObject()
  if ownerUserId.len > 0:
    users[ownerUserId] = %100
  %*{
    "users": users,
    "users_default": 0,
    "events_default": 0,
    "state_default": 50,
    "ban": 50,
    "kick": 50,
    "redact": 50,
    "invite": 0
  }

proc defaultJoinRulesContent(): JsonNode =
  %*{"join_rule": "invite"}

proc resolveRoomStateOwnerUserId(room: RoomData; fallbackUserId: string): string =
  result = room.creator
  if result.len == 0:
    result = fallbackUserId
  if result.len == 0:
    for userId, membership in room.members:
      if membership == "join":
        result = userId
        break

proc ensureDefaultPowerLevelsLocked(
    state: ServerState;
    roomId: string;
    fallbackUserId: string
): bool {.gcsafe.} =
  if roomId notin state.rooms:
    return false
  let key = stateKey("m.room.power_levels", "")
  if key in state.rooms[roomId].stateByKey:
    return false

  let room = state.rooms[roomId]
  for ev in room.timeline:
    if ev.eventType == "m.room.power_levels":
      var repairedRoom = room
      repairedRoom.stateByKey[key] = ev
      state.rooms[roomId] = repairedRoom
      return true

  let ownerUserId = resolveRoomStateOwnerUserId(room, fallbackUserId)

  discard state.appendEventLocked(
    roomId,
    if ownerUserId.len > 0: ownerUserId else: fallbackUserId,
    "m.room.power_levels",
    "",
    defaultPowerLevelsContent(ownerUserId)
  )
  true

proc ensureDefaultJoinRulesLocked(
    state: ServerState;
    roomId: string;
    fallbackUserId: string
): bool {.gcsafe.} =
  if roomId notin state.rooms:
    return false
  let key = stateKey("m.room.join_rules", "")
  if key in state.rooms[roomId].stateByKey:
    return false

  let room = state.rooms[roomId]
  for ev in room.timeline:
    if ev.eventType == "m.room.join_rules":
      var repairedRoom = room
      repairedRoom.stateByKey[key] = ev
      state.rooms[roomId] = repairedRoom
      return true

  let ownerUserId = resolveRoomStateOwnerUserId(room, fallbackUserId)
  discard state.appendEventLocked(
    roomId,
    if ownerUserId.len > 0: ownerUserId else: fallbackUserId,
    "m.room.join_rules",
    "",
    defaultJoinRulesContent()
  )
  true

proc ensureDefaultRoomStateLocked(
    state: ServerState;
    roomId: string;
    fallbackUserId: string
): bool {.gcsafe.} =
  let repairedPowerLevels = state.ensureDefaultPowerLevelsLocked(roomId, fallbackUserId)
  let repairedJoinRules = state.ensureDefaultJoinRulesLocked(roomId, fallbackUserId)
  repairedPowerLevels or repairedJoinRules

proc ensureRoomJoinedSet(state: ServerState; userId: string) =
  if userId notin state.userJoinedRooms:
    state.userJoinedRooms[userId] = initHashSet[string]()

proc applyMembership(state: ServerState; room: var RoomData; userId, membership: string) =
  room.members[userId] = membership
  state.ensureRoomJoinedSet(userId)
  if membership == "join":
    state.userJoinedRooms[userId].incl(room.roomId)
  else:
    state.userJoinedRooms[userId].excl(room.roomId)

proc appendEventLocked(
    state: ServerState;
    roomId, sender, eventType, stateKeyValue: string;
    content: JsonNode;
    redacts = ""
): MatrixEventRecord {.gcsafe.} =
  if roomId notin state.rooms:
    state.rooms[roomId] = RoomData(
      roomId: roomId,
      creator: sender,
      isDirect: false,
      members: initTable[string, string](),
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )

  var room = state.rooms[roomId]
  state.streamPos += 1
  let ev = MatrixEventRecord(
    streamPos: state.streamPos,
    eventId: "$" & $state.streamPos & "_" & randomString("", 8),
    roomId: roomId,
    sender: sender,
    eventType: eventType,
    stateKey: stateKeyValue,
    redacts: redacts,
    originServerTs: nowMs(),
    content: content
  )
  room.timeline.add(ev)
  if isStateEventForStorage(eventType, stateKeyValue):
    room.stateByKey[stateKey(eventType, stateKeyValue)] = ev
  if eventType == "m.room.member" and stateKeyValue.len > 0:
    let membership = content{"membership"}.getStr("")
    state.applyMembership(room, stateKeyValue, membership)
  state.rooms[roomId] = room
  ev

proc newUserId(state: ServerState; username: string): string =
  "@" & username & ":" & state.serverName

proc getSessionFromToken(
    state: ServerState;
    token: string;
    impersonateUserId: string
): tuple[ok: bool, session: AccessSession, errcode: string, message: string] =
  if token.len == 0:
    return (false, AccessSession(), "M_MISSING_TOKEN", "Missing access token.")

  if token in state.tokens:
    return (true, state.tokens[token], "", "")

  if token in state.appserviceByAsToken:
    let reg = state.appserviceByAsToken[token]
    var session = AccessSession(
      userId: resolveAppserviceSender(reg, state.serverName),
      deviceId: "appservice",
      issuedAtMs: nowMs(),
      isAppservice: true,
      appserviceId: reg.id
    )
    if impersonateUserId.len > 0:
      if userRegexMatches(reg, impersonateUserId):
        session.userId = impersonateUserId
      else:
        return (false, AccessSession(), "M_FORBIDDEN", "Appservice token cannot masquerade as " & impersonateUserId)
    return (true, session, "", "")

  (false, AccessSession(), "M_UNKNOWN_TOKEN", "Unknown access token.")

proc buildWhoamiPayload(session: AccessSession): JsonNode =
  %*{
    "user_id": session.userId,
    "device_id": session.deviceId,
    "is_guest": false
  }

proc buildCapabilitiesPayload(): JsonNode =
  %*{
    "capabilities": {
      "m.change_password": {"enabled": false},
      "m.room_versions": {
        "default": "11",
        "available": {
          "11": "stable",
          "10": "stable"
        }
      }
    }
  }

proc userProfilePayload(user: UserProfile): JsonNode =
  var payload = newJObject()
  payload["displayname"] = %user.displayName
  payload["avatar_url"] = %user.avatarUrl
  payload

proc roomJoinedForUser(state: ServerState; roomId, userId: string): bool =
  if roomId notin state.rooms:
    return false
  let room = state.rooms[roomId]
  room.members.getOrDefault(userId, "") == "join"

proc joinedRoomsForUser(state: ServerState; userId: string): seq[string] =
  result = @[]
  if userId notin state.userJoinedRooms:
    return
  for roomId in state.userJoinedRooms[userId]:
    result.add(roomId)
  result.sort(system.cmp[string])

proc roomStateArray(room: RoomData): JsonNode =
  var entries = newJArray()
  var allState: seq[MatrixEventRecord] = @[]
  for _, ev in room.stateByKey:
    allState.add(ev)
  allState.sort(proc(a, b: MatrixEventRecord): int = cmp(a.streamPos, b.streamPos))
  for ev in allState:
    entries.add(ev.eventToJson())
  entries

proc roomMembersArray(room: RoomData): JsonNode =
  var entries = newJArray()
  var allState: seq[MatrixEventRecord] = @[]
  for _, ev in room.stateByKey:
    if ev.eventType == "m.room.member":
      allState.add(ev)
  allState.sort(proc(a, b: MatrixEventRecord): int = cmp(a.streamPos, b.streamPos))
  for ev in allState:
    entries.add(ev.eventToJson())
  entries

proc joinedMembersPayload(state: ServerState; room: RoomData): JsonNode =
  result = %*{"joined": newJObject()}
  for userId, membership in room.members:
    if membership != "join":
      continue
    let user = state.users.getOrDefault(userId, UserProfile())
    result["joined"][userId] = %*{
      "display_name": user.displayName,
      "avatar_url": user.avatarUrl
    }

proc resolveRoomByJoinTarget(state: ServerState; roomIdOrAlias: string): string =
  if roomIdOrAlias in state.rooms:
    return roomIdOrAlias
  ""

proc nextRoomId(state: ServerState): string =
  state.roomCounter += 1
  "!" & $state.roomCounter & randomString("", 6) & ":" & state.serverName

proc queryAccessToken(req: Request): string =
  let fromHeader = req.headers.getOrDefault("Authorization").strip()
  if fromHeader.len > 7 and fromHeader.toLowerAscii().startsWith("bearer "):
    return fromHeader[7 .. ^1].strip()
  queryParam(req, "access_token")

proc resolveImpersonationUser(req: Request): string =
  queryParam(req, "user_id")

proc matchesAppserviceInterest(reg: AppserviceRegistration; ev: MatrixEventRecord; room: RoomData): bool =
  if reg.userRegexes.len == 0:
    return true
  if userRegexMatches(reg, ev.sender):
    return true
  for memberId, membership in room.members:
    if membership == "join" and userRegexMatches(reg, memberId):
      return true
  false

proc pathJoin(base, suffix: string): string =
  if base.endsWith("/"):
    base[0 ..< base.high] & suffix
  else:
    base & suffix

proc enqueueEventDeliveries(state: ServerState; ev: MatrixEventRecord) =
  if ev.roomId notin state.rooms:
    return
  let room = state.rooms[ev.roomId]
  for reg in state.appserviceRegs:
    if not matchesAppserviceInterest(reg, ev, room):
      continue
    state.deliveryCounter += 1
    let txnId = "t" & $state.deliveryCounter
    let payload = %*{
      "events": [ev.eventToJson()]
    }
    if ev.eventType == "m.room.redaction":
      info("Appservice redaction enqueue registration=" & reg.id &
        " room_id=" & ev.roomId &
        " event_id=" & ev.eventId &
        " redacts=" & ev.redacts)
    state.pendingDeliveries.add(AppserviceDelivery(
      registrationId: reg.id,
      registrationUrl: reg.url,
      hsToken: reg.hsToken,
      txnId: txnId,
      payload: payload,
      attempt: 0
    ))

proc computeRetryDelayMs(state: ServerState; attempt: int): int =
  let exp = min(attempt, 8)
  let raw = state.deliveryBaseMs * (1 shl exp)
  min(raw, state.deliveryMaxMs)

proc appserviceDeliveryUrl(delivery: AppserviceDelivery): string =
  pathJoin(delivery.registrationUrl, "/_matrix/app/v1/transactions/" & encodeUrl(delivery.txnId))

proc appserviceDeliveryHeaders(delivery: AppserviceDelivery): HttpHeaders =
  newHttpHeaders({
    "Content-Type": "application/json",
    "Authorization": "Bearer " & delivery.hsToken
  })

proc summarizeDeliveryResponse(body: string; maxLen = 240): string =
  let normalized = body.strip().replace("\n", "\\n")
  if normalized.len <= maxLen:
    return normalized
  normalized[0 ..< maxLen] & "..."

proc sendDelivery(delivery: AppserviceDelivery): Future[AppserviceDeliveryResult] {.async.} =
  let url = appserviceDeliveryUrl(delivery)
  let client = newAsyncHttpClient()
  defer:
    client.close()
  client.headers = appserviceDeliveryHeaders(delivery)
  try:
    let response = await client.request(
      url,
      httpMethod = HttpPut,
      body = $delivery.payload
    )
    let responseBody = await response.body
    result = AppserviceDeliveryResult(
      ok: response.code.int >= 200 and response.code.int < 300,
      statusCode: response.code.int,
      responseBody: responseBody,
      errorMessage: ""
    )
  except CatchableError as e:
    result = AppserviceDeliveryResult(
      ok: false,
      statusCode: 0,
      responseBody: "",
      errorMessage: e.msg
    )

proc retryDeliveryLater(state: ServerState; delivery: AppserviceDelivery; delayMs: int): Future[void] {.async.} =
  if delayMs > 0:
    await sleepAsync(delayMs)
  withLock state.lock:
    state.pendingDeliveries.add(delivery)

proc runDeliveryLoop(state: ServerState): Future[void] {.async.} =
  while true:
    var next = AppserviceDelivery(
      registrationId: "",
      registrationUrl: "",
      hsToken: "",
      txnId: "",
      payload: newJObject(),
      attempt: 0
    )
    var shouldStop = false
    withLock state.lock:
      if state.pendingDeliveries.len == 0 or state.deliveryInFlight >= state.deliveryMaxInflight:
        shouldStop = true
      else:
        next = state.pendingDeliveries[0]
        state.pendingDeliveries.delete(0)
        inc state.deliveryInFlight
    if shouldStop:
      return

    let deliveryResult = await sendDelivery(next)
    if deliveryResult.ok:
      withLock state.lock:
        inc state.deliverySent
        dec state.deliveryInFlight
      let evt = next.payload{"events"}[0]
      if evt.kind == JObject and evt{"type"}.getStr("") == "m.room.redaction":
        info("Appservice redaction delivered registration=" & next.registrationId &
          " txn=" & next.txnId &
          " room_id=" & evt{"room_id"}.getStr("") &
          " event_id=" & evt{"event_id"}.getStr("") &
          " redacts=" & evt{"redacts"}.getStr(evt{"content"}{"redacts"}.getStr("")))
      continue

    var retry = next
    retry.attempt += 1
    withLock state.lock:
      inc state.deliveryFailed
      dec state.deliveryInFlight
      if retry.attempt >= state.deliveryMaxAttempts:
        inc state.deliveryDeadLetters
        let detail =
          if deliveryResult.statusCode > 0:
            " status=" & $deliveryResult.statusCode &
              " body=" & summarizeDeliveryResponse(deliveryResult.responseBody)
          else:
            " err=" & deliveryResult.errorMessage
        warn("Appservice delivery dead-lettered registration=" & next.registrationId &
          " txn=" & next.txnId & " attempts=" & $retry.attempt & detail)
      else:
        let delay = state.computeRetryDelayMs(retry.attempt)
        let detail =
          if deliveryResult.statusCode > 0:
            " status=" & $deliveryResult.statusCode &
              " body=" & summarizeDeliveryResponse(deliveryResult.responseBody)
          else:
            " err=" & deliveryResult.errorMessage
        warn("Appservice delivery failed registration=" & next.registrationId &
          " txn=" & next.txnId & " attempt=" & $retry.attempt &
          " retry_in_ms=" & $delay & detail)
        asyncCheck state.retryDeliveryLater(retry, delay)

proc routeNeedsFederationAuth(routeName: string): bool =
  case routeName
  of "/_matrix/federation/{*path}", "/_matrix/key/v2/server", "/_matrix/key/v2/server/{key_id}",
      "/_matrix/key/{*path}":
    true
  else:
    false

proc routeBlockedWhenFederationDisabled(routeName: string): bool =
  case routeName
  of "/_matrix/federation/{*path}", "/_matrix/key/v2/server", "/_matrix/key/v2/server/{key_id}",
      "/_matrix/key/{*path}":
    true
  else:
    false

proc isRegisterAvailablePath(path: string): bool =
  path.startsWith("/_matrix/client/v3/register/available") or
    path.startsWith("/_matrix/client/r0/register/available")

proc isPublicRoomsPath(path: string): bool =
  path == "/_matrix/client/v3/publicRooms" or
    path == "/_matrix/client/r0/publicRooms"

proc isAuthGetPath(path: string): bool =
  case path
  of "/_matrix/client/v3/thirdparty/protocols",
      "/_matrix/client/r0/thirdparty/protocols",
      "/_matrix/client/v3/voip/turnServer",
      "/_matrix/client/r0/voip/turnServer",
      "/_matrix/client/v3/sync",
      "/_matrix/client/r0/sync",
      "/_matrix/client/v3/devices",
      "/_matrix/client/r0/devices",
      "/_matrix/client/v3/account/3pid",
      "/_matrix/client/r0/account/3pid",
      "/_matrix/client/v3/notifications",
      "/_matrix/client/r0/notifications",
      "/_matrix/client/v3/pushers",
      "/_matrix/client/r0/pushers",
      "/_matrix/client/v3/joined_rooms",
      "/_matrix/client/r0/joined_rooms":
    return true
  else:
    discard

  if path.startsWith("/_matrix/client/v3/keys/changes") or path.startsWith("/_matrix/client/r0/keys/changes"):
    return true
  if path.startsWith("/_matrix/client/v3/rooms/") or path.startsWith("/_matrix/client/r0/rooms/"):
    if path.endsWith("/members") or path.contains("/event/") or path.contains("/context/") or
        path.endsWith("/messages") or path.endsWith("/aliases"):
      return true
  false

proc isPostAuthPath(path: string): bool =
  case path
  of "/_matrix/client/v3/keys/query",
      "/_matrix/client/r0/keys/query",
      "/_matrix/client/v3/search",
      "/_matrix/client/r0/search",
      "/_matrix/client/v3/user_directory/search",
      "/_matrix/client/r0/user_directory/search":
    true
  else:
    false

proc isMediaConfigOrDownloadPath(path: string): bool =
  path == "/_matrix/media/v3/config" or
    path.startsWith("/_matrix/media/v3/download/") or
    path.startsWith("/_matrix/media/v3/thumbnail/") or
    path == "/_matrix/client/v1/media/config" or
    path.startsWith("/_matrix/client/v1/media/download/") or
    path == "/_matrix/media/r0/config" or
    path.startsWith("/_matrix/media/r0/download/") or
    path.startsWith("/_matrix/media/r0/thumbnail/") or
    path.startsWith("/_matrix/media/v1/")

proc isMediaUploadPath(path: string): bool =
  path == "/_matrix/media/v3/upload" or
    path == "/_matrix/media/v1/upload" or
    path == "/_matrix/media/r0/upload" or
    path == "/_matrix/client/v1/media/upload"

proc isMediaPreviewPath(path: string): bool =
  path.startsWith("/_matrix/media/v3/preview_url") or
    path.startsWith("/_matrix/media/r0/preview_url")

proc isProfilePath(path: string): bool =
  path.startsWith("/_matrix/client/v3/profile/") or
    path.startsWith("/_matrix/client/r0/profile/")

proc isDirectoryRoomPath(path: string): bool =
  path.startsWith("/_matrix/client/v3/directory/room/") or
    path.startsWith("/_matrix/client/r0/directory/room/")

proc isDeviceCollectionPath(path: string): bool =
  path == "/_matrix/client/v3/devices" or path == "/_matrix/client/r0/devices"

proc isDeviceDetailPath(path: string): bool =
  path.startsWith("/_matrix/client/v3/devices/") or
    path.startsWith("/_matrix/client/r0/devices/")

proc isDeleteDevicesPath(path: string): bool =
  path == "/_matrix/client/v3/delete_devices" or path == "/_matrix/client/r0/delete_devices"

proc isPushersSetPath(path: string): bool =
  path == "/_matrix/client/v3/pushers/set" or path == "/_matrix/client/r0/pushers/set"

proc isRoomStatePath(path: string): bool =
  (path.startsWith("/_matrix/client/v3/rooms/") or path.startsWith("/_matrix/client/r0/rooms/")) and
    path.contains("/state/")

proc isCreateRoomPath(path: string): bool =
  path == "/_matrix/client/v3/createRoom" or path == "/_matrix/client/r0/createRoom"

proc isEventsPath(path: string): bool =
  path == "/_matrix/client/v3/events" or path == "/_matrix/client/r0/events"

proc isKeysUploadOrClaimPath(path: string): bool =
  case path
  of "/_matrix/client/v3/keys/upload",
      "/_matrix/client/r0/keys/upload",
      "/_matrix/client/v3/keys/claim",
      "/_matrix/client/r0/keys/claim":
    true
  else:
    false

proc isUserFilterPath(path: string): bool =
  (path.startsWith("/_matrix/client/v3/user/") or path.startsWith("/_matrix/client/r0/user/")) and
    path.contains("/filter")

proc isUserAccountDataPath(path: string): bool =
  (path.startsWith("/_matrix/client/v3/user/") or path.startsWith("/_matrix/client/r0/user/")) and
    path.contains("/account_data/")

proc isRoomAccountDataPath(path: string): bool =
  (path.startsWith("/_matrix/client/v3/rooms/") or path.startsWith("/_matrix/client/r0/rooms/")) and
    path.contains("/account_data/")

proc isRoomReadMarkersPath(path: string): bool =
  (path.startsWith("/_matrix/client/v3/rooms/") or path.startsWith("/_matrix/client/r0/rooms/")) and
    path.endsWith("/read_markers")

proc isRoomTypingPath(path: string): bool =
  (path.startsWith("/_matrix/client/v3/rooms/") or path.startsWith("/_matrix/client/r0/rooms/")) and
    path.contains("/typing/")

proc isRoomReceiptPath(path: string): bool =
  (path.startsWith("/_matrix/client/v3/rooms/") or path.startsWith("/_matrix/client/r0/rooms/")) and
    path.contains("/receipt/")

proc isRoomInitialSyncPath(path: string): bool =
  (path.startsWith("/_matrix/client/v3/rooms/") or path.startsWith("/_matrix/client/r0/rooms/")) and
    path.endsWith("/initialSync")

proc isUnstableSummaryPath(path: string): bool =
  path.startsWith("/_matrix/client/unstable/im.nheko.summary/rooms/") and
    path.endsWith("/summary")

proc methodNotAllowed(req: Request) {.async.} =
  await respondJson(req, Http405, matrixError("M_UNRECOGNIZED", "Method Not Allowed"))

proc notFound(req: Request) {.async.} =
  await respondJson(req, Http404, matrixError("M_UNRECOGNIZED", "Not Found"))

proc notFoundWithCode(req: Request; errcode: string) {.async.} =
  await respondJson(req, Http404, matrixError(errcode, "Not Found"))

proc parseRequestJson(req: Request): tuple[ok: bool, value: JsonNode] =
  if req.body.len == 0:
    return (true, newJObject())
  try:
    let parsed = parseJson(req.body)
    (true, parsed)
  except CatchableError:
    (false, newJObject())

proc trimClientPath(path: string): string =
  if path.startsWith("/_matrix/client/v3/"):
    return path["/_matrix/client/v3/".len .. ^1]
  if path.startsWith("/_matrix/client/r0/"):
    return path["/_matrix/client/r0/".len .. ^1]
  ""

proc decodePath(value: string): string =
  try:
    decodeUrl(value)
  except CatchableError:
    value

proc roomIdFromRoomsPath(path, suffix: string): string =
  let trimmed = trimClientPath(path)
  if not trimmed.startsWith("rooms/"):
    return ""
  let marker = "/" & suffix
  if not trimmed.endsWith(marker):
    return ""
  let core = trimmed[0 ..< trimmed.len - marker.len]
  let segments = core.split('/')
  if segments.len < 2:
    return ""
  decodePath(segments[1])

proc mediaDownloadParts(path: string): tuple[ok: bool, mediaId: string] =
  let normalized = path.strip()
  let markers = [
    "/_matrix/media/v3/download/",
    "/_matrix/media/r0/download/",
    "/_matrix/media/v1/download/",
    "/_matrix/client/v1/media/download/"
  ]
  var tail = ""
  for marker in markers:
    if normalized.startsWith(marker):
      tail = normalized[marker.len .. ^1]
      break
  if tail.len == 0:
    return (false, "")
  let parts = tail.split("/")
  if parts.len < 2:
    return (false, "")
  let mediaId = decodeUrl(parts[1])
  if mediaId.len == 0:
    return (false, "")
  (true, mediaId)

proc roomAndSendFromPath(path: string): tuple[roomId: string, eventType: string, txnId: string] =
  let trimmed = trimClientPath(path)
  if not trimmed.startsWith("rooms/"):
    return ("", "", "")
  let segments = trimmed.split('/')
  if segments.len < 5:
    return ("", "", "")
  if segments[2] != "send":
    return ("", "", "")
  (
    decodePath(segments[1]),
    decodePath(segments[3]),
    decodePath(segments[4])
  )

proc roomAndRedactFromPath(path: string): tuple[roomId: string, eventId: string, txnId: string] =
  let trimmed = trimClientPath(path)
  if not trimmed.startsWith("rooms/"):
    return ("", "", "")
  let segments = trimmed.split('/')
  if segments.len < 5:
    return ("", "", "")
  if segments[2] != "redact":
    return ("", "", "")
  (
    decodePath(segments[1]),
    decodePath(segments[3]),
    decodePath(segments[4])
  )

proc roomAndStateEventFromPath(path: string): tuple[roomId: string, eventType: string, stateKeyValue: string, ok: bool] =
  let trimmed = trimClientPath(path)
  if not trimmed.startsWith("rooms/"):
    return ("", "", "", false)
  let segments = trimmed.split('/')
  if segments.len < 4 or segments.len > 5:
    return ("", "", "", false)
  if segments[2] != "state":
    return ("", "", "", false)
  if segments[3].len == 0:
    return ("", "", "", false)
  (
    decodePath(segments[1]),
    decodePath(segments[3]),
    if segments.len == 5: decodePath(segments[4]) else: "",
    true
  )

proc profilePathParts(path: string): tuple[userId: string, field: string] =
  let trimmed = trimClientPath(path)
  if not trimmed.startsWith("profile/"):
    return ("", "")
  let segments = trimmed.split('/')
  if segments.len < 2:
    return ("", "")
  let userId = decodePath(segments[1])
  let field = if segments.len >= 3: segments[2] else: ""
  (userId, field)

proc runNativeServer(cfg: LoadedConfig): int =
  let bindAddress = getConfigString(cfg.values, ["global.address", "address"], "127.0.0.1")
  let bindPort = getConfigInt(cfg.values, ["global.port", "port"], 8008)
  let serverName = getConfigString(cfg.values, ["global.server_name", "server_name"], "localhost")
  let listening = getConfigBool(cfg.values, ["global.listening", "listening"], true)
  let allowFederation = getConfigBool(
    cfg.values,
    ["global.allow_federation", "allow_federation"],
    true,
  )
  let syncTimeoutMin = max(0, getConfigInt(cfg.values, ["client_sync_timeout_min", "global.client_sync_timeout_min"], 1000))
  let syncTimeoutDefault = max(0, getConfigInt(cfg.values, ["client_sync_timeout_default", "global.client_sync_timeout_default"], 3000))
  let syncTimeoutMax = max(syncTimeoutMin, getConfigInt(cfg.values, ["client_sync_timeout_max", "global.client_sync_timeout_max"], 15000))
  let gifApiKey = block:
    let envKey = getEnv("BEENIM_GIPHY_API_KEY", "").strip()
    if envKey.len > 0:
      envKey
    else:
      let cfgKey = getConfigString(cfg.values, ["gifs.giphy_api_key", "global.gifs.giphy_api_key"], "").strip()
      if cfgKey.len > 0: cfgKey else: "LIVDSRZULELA"
  let gifApiBase = getConfigString(cfg.values, ["gifs.giphy_api_base", "global.gifs.giphy_api_base"], "https://api.giphy.com").strip(trailing = true, chars = {'/'})

  if not listening:
    info("Config sets listening=false; native runtime started without binding sockets")
    return 0

  let state = newServerState(cfg.values, serverName)
  var server = newAsyncHttpServer()

  proc cb(req: Request) {.async, gcsafe.} =
    let path = req.url.path
    let tokenPresent = hasAccessToken(req)
    let fedAuth = hasFederationAuth(req)
    let accessToken = queryAccessToken(req)
    let impersonateUser = resolveImpersonationUser(req)

    if path == "/_beenim/gifs/trending" or path == "/_beenim/gifs/search":
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return

      let baseUrl = requestBaseUrl(req, bindAddress, bindPort)
      if gifApiKey.len == 0:
        await respondJson(req, Http200, fallbackGifPayload(baseUrl))
        return

      var limit = 24
      let limitRaw = queryParam(req, "limit")
      if limitRaw.len > 0:
        try:
          limit = parseInt(limitRaw)
        except ValueError:
          discard
      limit = clampInt(limit, 1, 50)

      var rating = queryParam(req, "rating").strip()
      if rating.len == 0:
        rating = "pg-13"

      let isSearch = path.endsWith("/search")
      let queryText = queryParam(req, "q").strip()

      var upstreamUrl = gifApiBase & "/v1/gifs/trending?api_key=" & encodeUrl(gifApiKey) &
        "&limit=" & $limit & "&rating=" & encodeUrl(rating)
      if isSearch and queryText.len > 0:
        upstreamUrl = gifApiBase & "/v1/gifs/search?api_key=" & encodeUrl(gifApiKey) &
          "&q=" & encodeUrl(queryText) & "&limit=" & $limit &
          "&rating=" & encodeUrl(rating) & "&lang=en"

      let client = newAsyncHttpClient()
      defer:
        client.close()
      client.headers = newHttpHeaders({
        "Accept": "application/json",
        "User-Agent": "beenim-gif-proxy/1.0"
      })

      try:
        let upstreamResp = await client.request(upstreamUrl, httpMethod = HttpGet)
        let upstreamBody = await upstreamResp.body
        if upstreamResp.code != Http200:
          warn("GIF upstream returned HTTP " & $ord(upstreamResp.code) & "; serving fallback GIF list")
          await respondJson(req, Http200, fallbackGifPayload(baseUrl))
          return
        let parsed = parseJson(upstreamBody)
        let mapped = mapGiphyPayload(parsed, baseUrl)
        await respondJson(req, Http200, mapped)
      except CatchableError as e:
        warn("GIF upstream request failed (" & e.msg & "); serving fallback GIF list")
        await respondJson(req, Http200, fallbackGifPayload(baseUrl))
      return

    if path == "/_beenim/gifs/media":
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      let upstreamUrl = queryParam(req, "u").strip()
      if upstreamUrl.len == 0:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Missing u query parameter."))
        return
      if not isAllowedGifProxyUrl(upstreamUrl):
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Blocked GIF media host."))
        return

      var attempts = @[upstreamUrl]
      let httpFallback = giphyHttpFallbackUrl(upstreamUrl)
      if httpFallback.len > 0 and httpFallback != upstreamUrl:
        attempts.add(httpFallback)

      var body = ""
      var contentType = "image/gif"
      var lastError = ""
      var delivered = false

      for candidateUrl in attempts:
        let client = newAsyncHttpClient()
        defer:
          client.close()
        client.headers = newHttpHeaders({
          "Accept": "image/*,*/*",
          "User-Agent": "beenim-gif-proxy/1.0"
        })
        try:
          let upstreamResp = await client.request(candidateUrl, httpMethod = HttpGet)
          let candidateBody = await upstreamResp.body
          if upstreamResp.code.int < 200 or upstreamResp.code.int >= 300:
            lastError = "GIF media upstream returned HTTP " & $ord(upstreamResp.code)
            continue
          body = candidateBody
          if upstreamResp.headers.hasKey("Content-Type"):
            let rawContentType = $upstreamResp.headers["Content-Type"]
            if rawContentType.len > 0:
              contentType = rawContentType
          delivered = true
          if candidateUrl != upstreamUrl:
            warn("GIF media proxy fallback used HTTP transport for giphy media host")
          break
        except CatchableError as e:
          lastError = e.msg
          continue

      if not delivered:
        await respondJson(req, Http502, matrixError("M_UNKNOWN", "GIF media proxy failed: " & lastError))
        return

      let headers = newHttpHeaders({
        "Content-Type": contentType,
        "Cache-Control": "public, max-age=3600",
        "X-Content-Type-Options": "nosniff"
      })
      await req.respond(Http200, body, headers)
      return

    if path == "/_matrix/client/v3/login" or path == "/_matrix/client/r0/login":
      if req.reqMethod == HttpGet:
        await respondJson(req, Http200, loginTypesResponse())
        return

      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return

      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return

      let body = parsed.value
      let loginType = body{"type"}.getStr("m.login.password")
      var username = body{"identifier"}{"user"}.getStr("")
      if username.len == 0:
        username = body{"user"}.getStr("")
      if username.startsWith("@"):
        username = localpartFromUserId(username)
      let password = body{"password"}.getStr("")
      var deviceId = body{"device_id"}.getStr("")
      if deviceId.len == 0:
        deviceId = randomString("DEV", 12)

      var userId = ""
      var token = ""
      var loginErrCode = ""
      var loginErrMsg = ""
      withLock state.lock:
        if loginType == "m.login.password":
          if username.len == 0 or password.len == 0 or username notin state.usersByName:
            loginErrCode = "M_FORBIDDEN"
            loginErrMsg = "Invalid username or password."
          else:
            userId = state.usersByName[username]
            if userId notin state.users or state.users[userId].password != password:
              loginErrCode = "M_FORBIDDEN"
              loginErrMsg = "Invalid username or password."
            else:
              token = state.addTokenForUser(userId, deviceId)
              state.savePersistentState()
        elif loginType == "m.login.application_service":
          let sessionRes = state.getSessionFromToken(accessToken, impersonateUser)
          if not sessionRes.ok:
            loginErrCode = sessionRes.errcode
            loginErrMsg = sessionRes.message
          else:
            userId = sessionRes.session.userId
            token = state.addTokenForUser(userId, deviceId)
            state.savePersistentState()
        else:
          loginErrCode = "M_UNRECOGNIZED"
          loginErrMsg = "Unsupported login type."

      if loginErrCode.len > 0:
        let status = if loginErrCode == "M_FORBIDDEN": Http403 elif loginErrCode == "M_UNRECOGNIZED": Http400 else: Http401
        await respondJson(req, status, matrixError(loginErrCode, loginErrMsg))
        return

      await respondJson(req, Http200, %*{
        "user_id": userId,
        "access_token": token,
        "device_id": deviceId,
        "home_server": serverName
      })
      return

    if path == "/_matrix/client/v3/register" or path == "/_matrix/client/r0/register":
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var body = parsed.value
      var username = body{"username"}.getStr("")
      if username.len == 0:
        username = "user" & $nowMs()
      var password = body{"password"}.getStr("")
      if password.len == 0:
        password = randomString("pw_", 18)
      var deviceId = body{"device_id"}.getStr("")
      if deviceId.len == 0:
        deviceId = randomString("DEV", 12)

      var userId = ""
      var token = ""
      var registerErr = false
      withLock state.lock:
        if username in state.usersByName:
          registerErr = true
        else:
          userId = state.newUserId(username)
          state.usersByName[username] = userId
          state.users[userId] = UserProfile(
            userId: userId,
            username: username,
            password: password,
            displayName: username,
            avatarUrl: ""
          )
          token = state.addTokenForUser(userId, deviceId)
          state.savePersistentState()

      if registerErr:
        await respondJson(req, Http400, matrixError("M_USER_IN_USE", "User already exists."))
        return

      await respondJson(req, Http200, %*{
        "user_id": userId,
        "access_token": token,
        "device_id": deviceId,
        "home_server": serverName
      })
      return

    if path == "/_matrix/client/v3/account/whoami" or path == "/_matrix/client/r0/account/whoami":
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      await respondJson(req, Http200, buildWhoamiPayload(resolved.session))
      return

    if path == "/_matrix/client/v3/logout" or path == "/_matrix/client/r0/logout":
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and not resolved.session.isAppservice:
          state.removeToken(accessToken)
          state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      await respondJson(req, Http200, %*{})
      return

    if path == "/_matrix/client/v3/logout/all" or path == "/_matrix/client/r0/logout/all":
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and not resolved.session.isAppservice:
          state.removeAllTokensForUser(resolved.session.userId)
          state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      await respondJson(req, Http200, %*{})
      return

    if path == "/_matrix/client/v3/capabilities" or path == "/_matrix/client/r0/capabilities":
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      await respondJson(req, Http200, buildCapabilitiesPayload())
      return

    if path == "/_matrix/media/v3/config" or
        path == "/_matrix/media/r0/config" or
        path == "/_matrix/client/v1/media/config":
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      await respondJson(req, Http200, %*{"m.upload.size": 52_428_800})
      return

    if isMediaUploadPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      let contentType =
        if req.headers.hasKey("Content-Type"):
          req.headers["Content-Type"].split(";", maxsplit = 1)[0].strip()
        else:
          "application/octet-stream"
      let fileName = queryParam(req, "filename")
      var mediaId = ""
      withLock state.lock:
        mediaId = state.storeUploadedMedia(req.body, contentType, fileName)
      await respondJson(
        req,
        Http200,
        %*{"content_uri": "mxc://" & serverName & "/" & mediaId}
      )
      return

    let mediaDownload = mediaDownloadParts(path)
    if mediaDownload.ok:
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      let mediaPath = mediaDataPath(state.statePath, mediaDownload.mediaId)
      if not fileExists(mediaPath):
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Media not found."))
        return
      let meta = loadStoredMediaMeta(state, mediaDownload.mediaId)
      await respondRaw(
        req,
        Http200,
        readFile(mediaPath),
        contentType = meta.contentType,
        cacheControl = "public, max-age=31536000, immutable"
      )
      return

    if isSyncPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return

      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return

      var timeoutMs = syncTimeoutDefault
      let timeoutRaw = queryParam(req, "timeout")
      if timeoutRaw.len > 0:
        try:
          timeoutMs = parseInt(timeoutRaw)
        except ValueError:
          discard
      timeoutMs = max(syncTimeoutMin, min(syncTimeoutMax, timeoutMs))

      let sinceToken = queryParam(req, "since")
      let sincePos = parseSinceToken(sinceToken)
      let fullState = queryParam(req, "full_state").toLowerAscii() in ["1", "true", "yes"]

      proc buildSyncPayload(): JsonNode =
        var joinObj = newJObject()
        var nextBatch = "s0"
        withLock state.lock:
          let joinedRooms = state.joinedRoomsForUser(resolved.session.userId)
          for roomId in joinedRooms:
            if roomId notin state.rooms:
              continue
            let room = state.rooms[roomId]
            var timelineEvents = newJArray()
            for ev in room.timeline:
              if ev.streamPos > sincePos:
                timelineEvents.add(ev.eventToJson())

            var stateEvents = newJArray()
            if fullState or sincePos == 0:
              discard state.ensureDefaultRoomStateLocked(roomId, resolved.session.userId)
              var allState: seq[MatrixEventRecord] = @[]
              for _, stateEv in room.stateByKey:
                allState.add(stateEv)
              allState.sort(proc(a, b: MatrixEventRecord): int = cmp(a.streamPos, b.streamPos))
              for stateEv in allState:
                stateEvents.add(stateEv.eventToJson())

            if timelineEvents.len > 0 or stateEvents.len > 0 or fullState:
              joinObj[roomId] = %*{
                "timeline": {
                  "events": timelineEvents,
                  "limited": false,
                  "prev_batch": encodeSinceToken(sincePos),
                },
                "state": {
                  "events": stateEvents
                },
                "unread_notifications": {
                  "highlight_count": 0,
                  "notification_count": 0
                }
              }
          nextBatch = encodeSinceToken(state.streamPos)

        %*{
          "next_batch": nextBatch,
          "rooms": {
            "join": joinObj,
            "invite": {},
            "leave": {},
          },
          "presence": {
            "events": [],
          },
          "to_device": {
            "events": [],
          },
          "device_one_time_keys_count": {},
          "device_unused_fallback_key_types": [],
        }

      var payload = buildSyncPayload()
      if payload["rooms"]["join"].len == 0 and timeoutMs > 0:
        await sleepAsync(timeoutMs)
        payload = buildSyncPayload()
      await respondJson(req, Http200, payload)
      return

    if path == "/_matrix/client/v3/createRoom" or path == "/_matrix/client/r0/createRoom":
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var createdRoom = ""
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if not resolved.ok:
          discard
        else:
          createdRoom = state.nextRoomId()
          state.rooms[createdRoom] = RoomData(
            roomId: createdRoom,
            creator: resolved.session.userId,
            isDirect: parsed.value{"is_direct"}.getBool(false),
            members: initTable[string, string](),
            timeline: @[],
            stateByKey: initTable[string, MatrixEventRecord]()
          )

          let createContent =
            if parsed.value.hasKey("creation_content") and parsed.value["creation_content"].kind == JObject:
              parsed.value["creation_content"]
            else:
              newJObject()
          var createPayload = newJObject()
          createPayload["creator"] = %resolved.session.userId
          for key, val in createContent:
            createPayload[key] = val
          let evCreate = state.appendEventLocked(createdRoom, resolved.session.userId, "m.room.create", "", createPayload)
          state.enqueueEventDeliveries(evCreate)

          let evPowerLevels = state.appendEventLocked(
            createdRoom,
            resolved.session.userId,
            "m.room.power_levels",
            "",
            %*{
              "users": {resolved.session.userId: 100},
              "users_default": 0,
              "events_default": 0,
              "state_default": 50,
              "ban": 50,
              "kick": 50,
              "redact": 50,
              "invite": 0
            }
          )
          state.enqueueEventDeliveries(evPowerLevels)

          let evMember = state.appendEventLocked(
            createdRoom,
            resolved.session.userId,
            "m.room.member",
            resolved.session.userId,
            membershipContent("join")
          )
          state.enqueueEventDeliveries(evMember)

          let name = parsed.value{"name"}.getStr("")
          if name.len > 0:
            let evName = state.appendEventLocked(createdRoom, resolved.session.userId, "m.room.name", "", %*{"name": name})
            state.enqueueEventDeliveries(evName)

          let topic = parsed.value{"topic"}.getStr("")
          if topic.len > 0:
            let evTopic = state.appendEventLocked(createdRoom, resolved.session.userId, "m.room.topic", "", %*{"topic": topic})
            state.enqueueEventDeliveries(evTopic)

          if parsed.value.hasKey("initial_state") and parsed.value["initial_state"].kind == JArray:
            for entry in parsed.value["initial_state"]:
              if entry.kind != JObject:
                continue
              let eventType = entry{"type"}.getStr("")
              if eventType.len == 0:
                continue
              let skey = entry{"state_key"}.getStr("")
              let content = if entry.hasKey("content"): entry["content"] else: newJObject()
              let ev = state.appendEventLocked(createdRoom, resolved.session.userId, eventType, skey, content)
              state.enqueueEventDeliveries(ev)

          if parsed.value.hasKey("invite") and parsed.value["invite"].kind == JArray:
            for invitee in parsed.value["invite"]:
              if invitee.kind != JString:
                continue
              let inviteeId = invitee.getStr("")
              if inviteeId.len == 0:
                continue
              if inviteeId notin state.users:
                let localpart = localpartFromUserId(inviteeId)
                state.users[inviteeId] = UserProfile(
                  userId: inviteeId,
                  username: localpart,
                  password: "",
                  displayName: localpart,
                  avatarUrl: ""
                )
                if localpart.len > 0 and localpart notin state.usersByName:
                  state.usersByName[localpart] = inviteeId
              let evInvite = state.appendEventLocked(
                createdRoom,
                resolved.session.userId,
                "m.room.member",
                inviteeId,
                membershipContent("join")
              )
              state.enqueueEventDeliveries(evInvite)

          state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      await respondJson(req, Http200, %*{"room_id": createdRoom})
      return

    let joinPrefixV3 = "/_matrix/client/v3/join/"
    let joinPrefixR0 = "/_matrix/client/r0/join/"
    if (path.startsWith(joinPrefixV3) or path.startsWith(joinPrefixR0)) and req.reqMethod == HttpPost:
      let roomTarget = if path.startsWith(joinPrefixV3):
        decodePath(path[joinPrefixV3.len .. ^1])
      else:
        decodePath(path[joinPrefixR0.len .. ^1])
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var resolvedRoom = ""
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          resolvedRoom = state.resolveRoomByJoinTarget(roomTarget)
          if resolvedRoom.len > 0:
            let ev = state.appendEventLocked(
              resolvedRoom,
              resolved.session.userId,
              "m.room.member",
              resolved.session.userId,
              membershipContent("join")
            )
            state.enqueueEventDeliveries(ev)
            state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if resolvedRoom.len == 0:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      await respondJson(req, Http200, %*{"room_id": resolvedRoom})
      return

    let joinRoomById = roomIdFromRoomsPath(path, "join")
    if joinRoomById.len > 0:
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var foundRoom = false
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and joinRoomById in state.rooms:
          foundRoom = true
          let ev = state.appendEventLocked(
            joinRoomById,
            resolved.session.userId,
            "m.room.member",
            resolved.session.userId,
            membershipContent("join")
          )
          state.enqueueEventDeliveries(ev)
          state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not foundRoom:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      await respondJson(req, Http200, %*{"room_id": joinRoomById})
      return

    let inviteRoom = roomIdFromRoomsPath(path, "invite")
    if inviteRoom.len > 0:
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      let inviteeId = parsed.value{"user_id"}.getStr("")
      if inviteeId.len == 0:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "user_id is required."))
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var foundRoom = false
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and inviteRoom in state.rooms and state.roomJoinedForUser(inviteRoom, resolved.session.userId):
          foundRoom = true
          if inviteeId notin state.users:
            let localpart = localpartFromUserId(inviteeId)
            state.users[inviteeId] = UserProfile(
              userId: inviteeId,
              username: localpart,
              password: "",
              displayName: localpart,
              avatarUrl: ""
            )
            if localpart.len > 0 and localpart notin state.usersByName:
              state.usersByName[localpart] = inviteeId
          let ev = state.appendEventLocked(
            inviteRoom,
            resolved.session.userId,
            "m.room.member",
            inviteeId,
            membershipContent("join")
          )
          state.enqueueEventDeliveries(ev)
          state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not foundRoom:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      await respondJson(req, Http200, %*{})
      return

    let leaveRoom = roomIdFromRoomsPath(path, "leave")
    if leaveRoom.len > 0:
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var foundRoom = false
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and leaveRoom in state.rooms:
          foundRoom = true
          let ev = state.appendEventLocked(
            leaveRoom,
            resolved.session.userId,
            "m.room.member",
            resolved.session.userId,
            membershipContent("leave")
          )
          state.enqueueEventDeliveries(ev)
          state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not foundRoom:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      await respondJson(req, Http200, %*{})
      return

    let joinedMembersRoom = roomIdFromRoomsPath(path, "joined_members")
    if joinedMembersRoom.len > 0:
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var foundRoom = false
      var payload = %*{"joined": newJObject()}
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and joinedMembersRoom in state.rooms:
          if resolved.session.isAppservice or state.roomJoinedForUser(joinedMembersRoom, resolved.session.userId):
            foundRoom = true
            payload = joinedMembersPayload(state, state.rooms[joinedMembersRoom])
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not foundRoom:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      await respondJson(req, Http200, payload)
      return

    let membersRoom = roomIdFromRoomsPath(path, "members")
    if membersRoom.len > 0:
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var foundRoom = false
      var payload = %*{"chunk": newJArray()}
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and membersRoom in state.rooms:
          if resolved.session.isAppservice or state.roomJoinedForUser(membersRoom, resolved.session.userId):
            foundRoom = true
            payload = %*{"chunk": roomMembersArray(state.rooms[membersRoom])}
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not foundRoom:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      await respondJson(req, Http200, payload)
      return

    let messagesRoom = roomIdFromRoomsPath(path, "messages")
    if messagesRoom.len > 0:
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      let dir = queryParam(req, "dir").strip().toLowerAscii()
      if dir notin ["", "b", "f"]:
        await respondJson(req, Http400, matrixError("M_INVALID_PARAM", "dir must be 'b' or 'f'."))
        return
      var limit = 25
      let limitRaw = queryParam(req, "limit")
      if limitRaw.len > 0:
        try:
          limit = max(1, min(200, parseInt(limitRaw)))
        except ValueError:
          discard

      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var foundRoom = false
      var payload = %*{
        "chunk": newJArray(),
        "start": "",
        "end": ""
      }
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and messagesRoom in state.rooms:
          if resolved.session.isAppservice or state.roomJoinedForUser(messagesRoom, resolved.session.userId):
            foundRoom = true
            let room = state.rooms[messagesRoom]
            let fromToken = queryParam(req, "from")
            var fromPos = parseSinceToken(fromToken)
            if fromPos <= 0:
              if room.timeline.len > 0:
                fromPos = room.timeline[^1].streamPos + 1
              else:
                fromPos = state.streamPos + 1

            var chunk = newJArray()
            if dir == "" or dir == "b":
              var endPos = 0'i64
              for idx in countdown(room.timeline.high, 0):
                let ev = room.timeline[idx]
                if ev.streamPos >= fromPos:
                  continue
                chunk.add(ev.eventToJson())
                endPos = ev.streamPos
                if chunk.len >= limit:
                  break
              payload["chunk"] = chunk
              payload["start"] = %encodeSinceToken(fromPos)
              payload["end"] = %(if endPos > 0: encodeSinceToken(endPos) else: "")
            else:
              var endPos = 0'i64
              for ev in room.timeline:
                if ev.streamPos <= fromPos:
                  continue
                chunk.add(ev.eventToJson())
                endPos = ev.streamPos
                if chunk.len >= limit:
                  break
              payload["chunk"] = chunk
              payload["start"] = %encodeSinceToken(fromPos)
              payload["end"] = %(if endPos > 0: encodeSinceToken(endPos) else: "")
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not foundRoom:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      await respondJson(req, Http200, payload)
      return

    if path.endsWith("/state") and (path.startsWith("/_matrix/client/v3/rooms/") or path.startsWith("/_matrix/client/r0/rooms/")):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      let roomId = roomIdFromRoomsPath(path, "state")
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var payload: JsonNode = newJArray()
      var foundRoom = false
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and roomId in state.rooms:
          if resolved.session.isAppservice or state.roomJoinedForUser(roomId, resolved.session.userId):
            foundRoom = true
            discard state.ensureDefaultRoomStateLocked(roomId, resolved.session.userId)
            payload = roomStateArray(state.rooms[roomId])
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not foundRoom:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      await respondJson(req, Http200, payload)
      return

    let stateParts = roomAndStateEventFromPath(path)
    if stateParts.ok:
      if req.reqMethod != HttpGet and req.reqMethod != HttpPut:
        await methodNotAllowed(req)
        return

      if req.reqMethod == HttpGet:
        var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
        var roomOk = false
        var foundState = false
        var payload = newJObject()
        withLock state.lock:
          resolved = state.getSessionFromToken(accessToken, impersonateUser)
          if resolved.ok and stateParts.roomId in state.rooms:
            if resolved.session.isAppservice or state.roomJoinedForUser(stateParts.roomId, resolved.session.userId):
              roomOk = true
              if stateParts.eventType in ["m.room.power_levels", "m.room.join_rules"]:
                discard state.ensureDefaultRoomStateLocked(stateParts.roomId, resolved.session.userId)
              let room = state.rooms[stateParts.roomId]
              let key = stateKey(stateParts.eventType, stateParts.stateKeyValue)
              if key in room.stateByKey:
                foundState = true
                payload = room.stateByKey[key].content
        if not resolved.ok:
          await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
          return
        if not roomOk:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
          return
        if not foundState:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "State event not found."))
          return
        await respondJson(req, Http200, payload)
        return

      let parsed = parseRequestJson(req)
      if not parsed.ok:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var roomOk = false
      var sentEventId = ""
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and stateParts.roomId in state.rooms:
          if resolved.session.isAppservice or state.roomJoinedForUser(stateParts.roomId, resolved.session.userId):
            roomOk = true
            let ev = state.appendEventLocked(
              stateParts.roomId,
              resolved.session.userId,
              stateParts.eventType,
              stateParts.stateKeyValue,
              parsed.value
            )
            sentEventId = ev.eventId
            state.enqueueEventDeliveries(ev)
            state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not roomOk:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      await respondJson(req, Http200, %*{"event_id": sentEventId})
      return

    let sendParts = roomAndSendFromPath(path)
    if sendParts.roomId.len > 0:
      if req.reqMethod != HttpPut:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var sentEventId = ""
      var roomOk = false
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and sendParts.roomId in state.rooms:
          if resolved.session.isAppservice or state.roomJoinedForUser(sendParts.roomId, resolved.session.userId):
            roomOk = true
            let redacts =
              if sendParts.eventType == "m.room.redaction":
                parsed.value{"redacts"}.getStr("")
              else:
                ""
            let ev = state.appendEventLocked(
              sendParts.roomId,
              resolved.session.userId,
              sendParts.eventType,
              "",
              parsed.value,
              redacts = redacts
            )
            sentEventId = ev.eventId
            state.enqueueEventDeliveries(ev)
            state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not roomOk:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      await respondJson(req, Http200, %*{"event_id": sentEventId})
      return

    let redactParts = roomAndRedactFromPath(path)
    if redactParts.roomId.len > 0:
      if req.reqMethod != HttpPut:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      parsed.value["redacts"] = %redactParts.eventId
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var sentEventId = ""
      var roomOk = false
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and redactParts.roomId in state.rooms:
          if resolved.session.isAppservice or state.roomJoinedForUser(redactParts.roomId, resolved.session.userId):
            roomOk = true
            let ev = state.appendEventLocked(
              redactParts.roomId,
              resolved.session.userId,
              "m.room.redaction",
              "",
              parsed.value,
              redacts = redactParts.eventId
            )
            sentEventId = ev.eventId
            state.enqueueEventDeliveries(ev)
            state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not roomOk:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      await respondJson(req, Http200, %*{"event_id": sentEventId})
      return

    let profileParts = profilePathParts(path)
    if profileParts.userId.len > 0:
      if req.reqMethod == HttpGet:
        var found = false
        var payload = newJObject()
        withLock state.lock:
          if profileParts.userId in state.users:
            let user = state.users[profileParts.userId]
            found = true
            if profileParts.field == "displayname":
              payload = %*{"displayname": user.displayName}
            elif profileParts.field == "avatar_url":
              payload = %*{"avatar_url": user.avatarUrl}
            else:
              payload = userProfilePayload(user)
        if not found:
          await notFoundWithCode(req, "M_NOT_FOUND")
          return
        await respondJson(req, Http200, payload)
        return

      if req.reqMethod != HttpPut:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var forbidden = false
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          if not resolved.session.isAppservice and resolved.session.userId != profileParts.userId:
            forbidden = true
          else:
            if profileParts.userId notin state.users:
              let local = localpartFromUserId(profileParts.userId)
              state.users[profileParts.userId] = UserProfile(
                userId: profileParts.userId,
                username: local,
                password: "",
                displayName: local,
                avatarUrl: ""
              )
              if local.len > 0 and local notin state.usersByName:
                state.usersByName[local] = profileParts.userId
            var user = state.users[profileParts.userId]
            if profileParts.field == "displayname":
              user.displayName = parsed.value{"displayname"}.getStr(user.displayName)
            elif profileParts.field == "avatar_url":
              user.avatarUrl = parsed.value{"avatar_url"}.getStr(user.avatarUrl)
            state.users[profileParts.userId] = user
            state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if forbidden:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Cannot edit another user profile."))
        return
      await respondJson(req, Http200, %*{})
      return

    if path == "/_matrix/client/versions":
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      await respondJson(req, Http200, versionsResponse())
      return

    if isAppservicePingPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let registrationId = extractAppservicePingRegistrationId(path)
      let response = appservicePingResponseForRegs(
        state.appserviceRegs,
        registrationId,
        queryAccessToken(req)
      )
      await respondJson(req, response.code, response.payload)
      return

    if path == "/_matrix/client/v3/login" or path == "/_matrix/client/r0/login":
      if req.reqMethod == HttpGet:
        await respondJson(req, Http200, loginTypesResponse())
        return

    if isRegisterAvailablePath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      if tokenPresent:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      else:
        await respondJson(req, Http200, %*{"available": true})
      return

    if isPublicRoomsPath(path):
      if req.reqMethod != HttpGet and req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      if req.reqMethod == HttpGet:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing or invalid access token."))
      elif not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isProfilePath(path):
      if req.reqMethod == HttpGet:
        if not tokenPresent:
          await notFoundWithCode(req, "M_NOT_FOUND")
        else:
          await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
        return
      if req.reqMethod != HttpPut:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isDirectoryRoomPath(path):
      if req.reqMethod == HttpGet:
        if not tokenPresent:
          await notFoundWithCode(req, "M_NOT_FOUND")
        else:
          await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
        return
      if req.reqMethod != HttpPut and req.reqMethod != HttpDelete:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isDeviceCollectionPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isDeviceDetailPath(path):
      if req.reqMethod != HttpGet and req.reqMethod != HttpPut and req.reqMethod != HttpDelete:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isDeleteDevicesPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isPushersSetPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isRoomStatePath(path):
      if req.reqMethod != HttpGet and req.reqMethod != HttpPut:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isCreateRoomPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isEventsPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isKeysUploadOrClaimPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isUserFilterPath(path):
      if req.reqMethod != HttpGet and req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isUserAccountDataPath(path):
      if req.reqMethod != HttpGet and req.reqMethod != HttpPut:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isRoomAccountDataPath(path):
      await notFound(req)
      return

    if isRoomReadMarkersPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isRoomTypingPath(path):
      if req.reqMethod != HttpPut:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isRoomReceiptPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isRoomInitialSyncPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isUnstableSummaryPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Forbidden."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isPostAuthPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isAuthGetPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isMediaConfigOrDownloadPath(path):
      await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Unauthenticated media is disabled."))
      return

    if isMediaPreviewPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if path == "/_matrix/client/v3/register" or path == "/_matrix/client/r0/register":
      if req.reqMethod == HttpGet:
        await methodNotAllowed(req)
        return
    if path == "/_matrix/client/v3/logout" or path == "/_matrix/client/r0/logout":
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
    if path == "/_matrix/client/v3/logout/all" or path == "/_matrix/client/r0/logout/all":
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
    if path == "/_matrix/client/v3/capabilities" or path == "/_matrix/client/r0/capabilities":
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return

    if path == "/_tuwunel/server_version":
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      await respondJson(req, Http200, %*{
        "name": "Tuwunel",
        "version": RustBaselineVersion,
      })
      return

    if path == "/_tuwunel/local_user_count":
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Forbidden."))
      return

    if path == "/client/server.json":
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      await notFoundWithCode(req, "M_NOT_FOUND")
      return

    if path == "/.well-known/matrix/server":
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      if not allowFederation:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Federation is disabled."))
      else:
        await respondJson(req, Http200, %*{"m.server": serverName})
      return

    let routeName = resolveRouteName(path)
    if routeName.len == 0:
      await notFound(req)
      return

    if routeBlockedWhenFederationDisabled(routeName) and not allowFederation:
      await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Federation is disabled."))
      return

    if routeNeedsFederationAuth(routeName) and not fedAuth:
      await respondJson(req, Http401, matrixError("M_UNAUTHORIZED", "Missing federation authentication."))
      return

    if routeNeedsAccessToken(routeName) and not tokenPresent:
      await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      return

    if routeNeedsAccessToken(routeName) and tokenPresent:
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return

    await respondJson(
      req,
      Http501,
      matrixError("M_NOT_YET_IMPLEMENTED", "Route registered but not yet behaviorally ported: " & routeName),
    )

  info(fmt"Starting native Nim runtime on {bindAddress}:{bindPort}")
  info("Rust delegation is disabled in runtime startup path")
  proc deliveryPump() {.async.} =
    while true:
      await state.runDeliveryLoop()
      await sleepAsync(250)
  asyncCheck deliveryPump()
  waitFor server.serve(Port(bindPort), cb, address = bindAddress)
  0

proc main*(): int =
  info("Starting native Nim runtime")

  let a = parseArgs()

  if a.showVersion:
    echo "tuwunel-nim " & Version
    return 0

  if a.showHelp:
    echo usage()
    return 0

  if a.unknown.len > 0:
    return die("Unknown flags: " & $a.unknown)

  let cfgRes = loadConfigCompatibility(a)
  if not cfgRes.ok:
    return die(cfgRes.err)

  for p in cfgRes.cfg.configPaths:
    if not fileExists(p):
      warn(fmt"Config path does not exist yet: {p}")

  info("Bootstrapped compatibility config loader for tuwunel-nim")
  info(
    fmt"config_paths={cfgRes.cfg.configPaths.len} loaded_files={cfgRes.cfg.stats.loadedFiles.len} " &
    fmt"env_overrides={cfgRes.cfg.stats.envOverrides.len} option_overrides={cfgRes.cfg.stats.optionOverrides.len}"
  )
  debug("effective_config:\n" & renderFlatConfig(cfgRes.cfg.values))

  if boolEnv("TUWUNEL_NIM_BOOTSTRAP_ONLY", false):
    info("Bootstrap-only mode enabled; skipping runtime server loop")
    return 0

  runNativeServer(cfgRes.cfg)

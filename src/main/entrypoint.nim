import std/[algorithm, asynchttpserver, asyncdispatch, base64, httpclient, json, locks, options, os, random, re, sets, sha1, strformat, strutils, tables, times, uri]
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
  ReportReasonMaxLen = 750
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

proc normalizeAppservicePingPath(path: string): string =
  result = path.strip()
  while result.len > 1 and result.endsWith("/"):
    result.setLen(result.len - 1)

proc looksLikeAppservicePingPath(path: string): bool =
  let normalized = normalizeAppservicePingPath(path)
  normalized.startsWith("/_matrix/client/") and
    "/appservice/" in normalized and
    normalized.endsWith("/ping")

proc parseAppservicePingPath*(
    path: string
): tuple[ok: bool, registrationId: string, normalizedPath: string] =
  const Prefix = "/_matrix/client/v1/appservice/"
  const Suffix = "/ping"
  result = (false, "", normalizeAppservicePingPath(path))
  if not result.normalizedPath.startsWith(Prefix) or not result.normalizedPath.endsWith(Suffix):
    return
  let startIdx = Prefix.len
  let endIdx = result.normalizedPath.len - Suffix.len
  if endIdx <= startIdx:
    return
  let raw = result.normalizedPath[startIdx ..< endIdx]
  if raw.len == 0 or '/' in raw:
    return
  try:
    result.registrationId = decodeUrl(raw)
    result.ok = result.registrationId.len > 0
  except CatchableError:
    discard

proc isAppservicePingPath*(path: string): bool =
  parseAppservicePingPath(path).ok

proc extractAppservicePingRegistrationId*(path: string): string =
  parseAppservicePingPath(path).registrationId

proc logRejectedAppservicePing(
    reqMethod: HttpMethod,
    path: string,
    registrationId: string,
    authPresent: bool,
    reason: string
) =
  debug(
    "Rejected appservice ping" &
    " method=" & $reqMethod &
    " path=" & path &
    " registration_id=" & (if registrationId.len > 0: registrationId else: "-") &
    " auth_present=" & (if authPresent: "1" else: "0") &
    " reason=" & reason
  )

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

proc respondJson(req: Request; code: HttpCode; payload: JsonNode): Future[void] =
  let headers = newHttpHeaders({
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
  })
  req.respond(code, $payload, headers)

proc respondRedirect(req: Request; location: string; cookie = ""): Future[void] =
  let headers = newHttpHeaders({
    "Location": location,
    "Cache-Control": "no-store",
  })
  if cookie.len > 0:
    headers["Set-Cookie"] = cookie
  req.respond(Http302, "", headers)

proc respondRaw(
    req: Request;
    code: HttpCode;
    body: string;
    contentType = "application/octet-stream";
    cacheControl = "no-store";
    contentDisposition = ""
): Future[void] =
  let headers = newHttpHeaders({
    "Content-Type": contentType,
    "Cache-Control": cacheControl,
  })
  if contentDisposition.len > 0:
    headers["Content-Disposition"] = contentDisposition
  req.respond(code, body, headers)

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

proc federationAuthOriginHeader(raw: string): string =
  var auth = raw.strip()
  if auth.toLowerAscii().startsWith("x-matrix"):
    auth =
      if auth.len > "x-matrix".len:
        auth["x-matrix".len .. ^1].strip()
      else:
        ""
    if auth.startsWith(","):
      auth = auth[1 .. ^1].strip()
  for part in auth.split(','):
    let trimmed = part.strip()
    let eq = trimmed.find('=')
    if eq < 0:
      continue
    let key = trimmed[0 ..< eq].strip().toLowerAscii()
    if key != "origin":
      continue
    var value = trimmed[(eq + 1) .. ^1].strip()
    value = value.strip(chars = {'"'})
    return value
  ""

proc federationAuthOrigin(req: Request): string =
  if not req.headers.hasKey("Authorization"):
    return ""
  federationAuthOriginHeader(req.headers["Authorization"])

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

proc isSyncV5Path(path: string): bool =
  path == "/_matrix/client/unstable/org.matrix.simplified_msc3575/sync" or
    path == "/_matrix/client/unstable/org.matrix.msc3575/sync"

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

proc queryParamValues(req: Request; key: string): seq[string] =
  result = @[]
  let query = req.url.query
  if query.len == 0:
    return

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
      result.add(decodeUrl(rawVal, decodePlus = true))
    except CatchableError:
      result.add(rawVal)

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
    blurhash: string
    timezone: string
    profileFields: Table[string, JsonNode]

  DeviceRecord = object
    userId: string
    deviceId: string
    displayName: string
    lastSeenIp: string
    lastSeenTs: int64

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

  AccountDataRecord = object
    streamPos: int64
    userId: string
    roomId: string
    eventType: string
    content: JsonNode

  TypingRecord = object
    roomId: string
    userId: string
    expiresAtMs: int64
    streamPos: int64

  ReceiptRecord = object
    roomId: string
    eventId: string
    receiptType: string
    userId: string
    threadId: string
    ts: int64
    streamPos: int64

  PresenceRecord = object
    userId: string
    presence: string
    statusMsg: string
    currentlyActive: bool
    lastActiveTs: int64
    streamPos: int64

  ReportRecord = object
    reportId: string
    reporterUserId: string
    roomId: string
    eventId: string
    reason: string
    score: int
    ts: int64
    streamPos: int64

  BackupVersionRecord = object
    userId: string
    version: string
    algorithm: string
    authData: JsonNode
    etag: string
    streamPos: int64

  BackupSessionRecord = object
    userId: string
    version: string
    roomId: string
    sessionId: string
    sessionData: JsonNode
    streamPos: int64

  DeviceKeyRecord = object
    userId: string
    deviceId: string
    keyData: JsonNode
    streamPos: int64

  OneTimeKeyRecord = object
    userId: string
    deviceId: string
    algorithm: string
    keyId: string
    keyData: JsonNode
    streamPos: int64

  FallbackKeyRecord = object
    userId: string
    deviceId: string
    algorithm: string
    keyId: string
    keyData: JsonNode
    used: bool
    streamPos: int64

  DehydratedDeviceRecord = object
    userId: string
    deviceId: string
    deviceData: JsonNode
    streamPos: int64

  CrossSigningKeyRecord = object
    userId: string
    keyType: string
    keyData: JsonNode
    streamPos: int64

  ToDeviceEventRecord = object
    targetUserId: string
    targetDeviceId: string
    sender: string
    eventType: string
    txnId: string
    content: JsonNode
    streamPos: int64

  OpenIdTokenRecord = object
    accessToken: string
    userId: string
    expiresAtMs: int64
    streamPos: int64

  LoginTokenRecord = object
    loginToken: string
    userId: string
    expiresAtMs: int64

  RefreshTokenRecord = object
    refreshToken: string
    userId: string
    deviceId: string
    expiresAtMs: int64

  SsoSessionRecord = object
    sessionId: string
    idpId: string
    redirectUrl: string
    codeVerifier: string
    nonce: string
    userId: string
    expiresAtMs: int64

  SsoProvider = object
    id: string
    brand: string
    name: string
    icon: string
    clientId: string
    clientSecret: string
    authorizationUrl: string
    tokenUrl: string
    userInfoUrl: string
    callbackUrl: string
    scope: seq[string]
    defaultProvider: bool
    registration: bool
    checkCookie: bool
    grantSessionTtlMs: int64

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
    loginTokens: Table[string, LoginTokenRecord]
    refreshTokens: Table[string, RefreshTokenRecord]
    ssoSessions: Table[string, SsoSessionRecord]
    devices: Table[string, DeviceRecord]
    rooms: Table[string, RoomData]
    accountData: Table[string, AccountDataRecord]
    filters: Table[string, JsonNode]
    pushers: Table[string, JsonNode]
    pushRules: Table[string, JsonNode]
    backupCounter: int64
    backupVersions: Table[string, BackupVersionRecord]
    backupSessions: Table[string, BackupSessionRecord]
    deviceKeys: Table[string, DeviceKeyRecord]
    oneTimeKeys: Table[string, OneTimeKeyRecord]
    fallbackKeys: Table[string, FallbackKeyRecord]
    dehydratedDevices: Table[string, DehydratedDeviceRecord]
    crossSigningKeys: Table[string, CrossSigningKeyRecord]
    toDeviceEvents: Table[string, ToDeviceEventRecord]
    toDeviceTxnIds: HashSet[string]
    openIdTokens: Table[string, OpenIdTokenRecord]
    typing: Table[string, TypingRecord]
    typingUpdates: Table[string, int64]
    receipts: Table[string, ReceiptRecord]
    presence: Table[string, PresenceRecord]
    reports: seq[ReportRecord]
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

proc deviceKey(userId, deviceId: string): string =
  userId & "\x1f" & deviceId

proc accountDataKey(roomId, userId, eventType: string): string =
  roomId & "\x1f" & userId & "\x1f" & eventType

proc filterKey(userId, filterId: string): string =
  userId & "\x1f" & filterId

proc pusherKey(userId, appId, pushKey: string): string =
  userId & "\x1f" & appId & "\x1f" & pushKey

proc pushRuleKey(userId, scope, kind, ruleId: string): string =
  userId & "\x1f" & scope & "\x1f" & kind & "\x1f" & ruleId

proc backupVersionKey(userId, version: string): string =
  userId & "\x1f" & version

proc backupSessionKey(userId, version, roomId, sessionId: string): string =
  userId & "\x1f" & version & "\x1f" & roomId & "\x1f" & sessionId

proc oneTimeKeyStoreKey(userId, deviceId, algorithm, keyId: string): string =
  userId & "\x1f" & deviceId & "\x1f" & algorithm & "\x1f" & keyId

proc crossSigningKey(userId, keyType: string): string =
  userId & "\x1f" & keyType

proc toDeviceEventKey(userId, deviceId: string; streamPos: int64): string =
  userId & "\x1f" & deviceId & "\x1f" & $streamPos

proc toDeviceTxnKey(sender, deviceId, txnId: string): string =
  sender & "\x1f" & deviceId & "\x1f" & txnId

proc typingKey(roomId, userId: string): string =
  roomId & "\x1f" & userId

proc receiptKey(roomId, eventId, receiptType, userId, threadId: string): string =
  roomId & "\x1f" & eventId & "\x1f" & receiptType & "\x1f" & userId & "\x1f" & threadId

proc isStateEventForStorage(eventType, stateKeyValue: string): bool {.gcsafe.}

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

proc isEmptyObjectJson(node: JsonNode): bool =
  node.kind == JObject and node.len == 0

proc accountDataEventJson(record: AccountDataRecord): JsonNode =
  %*{
    "type": record.eventType,
    "content": record.content,
  }

proc accountDataEventsForSync(
    state: ServerState;
    userId, roomId: string;
    sincePos: int64;
    initial: bool
): JsonNode =
  result = newJArray()
  var records: seq[AccountDataRecord] = @[]
  for _, record in state.accountData:
    if record.userId == userId and record.roomId == roomId:
      if initial:
        if not isEmptyObjectJson(record.content):
          records.add(record)
      elif record.streamPos > sincePos:
        records.add(record)
  records.sort(proc(a, b: AccountDataRecord): int = cmp(a.streamPos, b.streamPos))
  for record in records:
    result.add(record.accountDataEventJson())

proc setTypingLocked(
    state: ServerState;
    roomId, userId: string;
    typing: bool;
    timeoutMs: int64
) =
  inc state.streamPos
  if typing:
    let clampedTimeout =
      if timeoutMs < 1000'i64:
        1000'i64
      elif timeoutMs > 300000'i64:
        300000'i64
      else:
        timeoutMs
    state.typing[typingKey(roomId, userId)] = TypingRecord(
      roomId: roomId,
      userId: userId,
      expiresAtMs: nowMs() + clampedTimeout,
      streamPos: state.streamPos,
    )
  else:
    state.typing.del(typingKey(roomId, userId))
  state.typingUpdates[roomId] = state.streamPos

proc pruneExpiredTypingLocked(state: ServerState; nowValue = nowMs()) =
  var expired: seq[TypingRecord] = @[]
  for _, record in state.typing:
    if record.expiresAtMs <= nowValue:
      expired.add(record)
  for record in expired:
    state.typing.del(typingKey(record.roomId, record.userId))
    inc state.streamPos
    state.typingUpdates[record.roomId] = state.streamPos

proc typingEventsForSync(
    state: ServerState;
    roomId: string;
    sincePos: int64;
    initial: bool
): JsonNode =
  result = newJArray()
  let roomUpdatePos = state.typingUpdates.getOrDefault(roomId, 0'i64)
  if not initial and roomUpdatePos <= sincePos:
    return

  var userIds: seq[string] = @[]
  for _, record in state.typing:
    if record.roomId == roomId:
      userIds.add(record.userId)
  userIds.sort(system.cmp[string])

  if userIds.len == 0 and initial:
    return

  var ids = newJArray()
  for userId in userIds:
    ids.add(%userId)
  result.add(%*{
    "type": "m.typing",
    "content": {
      "user_ids": ids
    }
  })

proc setReceiptLocked(
    state: ServerState;
    roomId, eventId, receiptType, userId, threadId: string
): ReceiptRecord =
  inc state.streamPos
  result = ReceiptRecord(
    roomId: roomId,
    eventId: eventId,
    receiptType: receiptType,
    userId: userId,
    threadId: threadId,
    ts: nowMs(),
    streamPos: state.streamPos,
  )
  state.receipts[receiptKey(roomId, eventId, receiptType, userId, threadId)] = result

proc receiptEventsForSync(
    state: ServerState;
    roomId: string;
    sincePos: int64;
    initial: bool
): JsonNode =
  result = newJArray()
  var records: seq[ReceiptRecord] = @[]
  for _, record in state.receipts:
    if record.roomId == roomId and (initial or record.streamPos > sincePos):
      records.add(record)
  if records.len == 0:
    return
  records.sort(proc(a, b: ReceiptRecord): int = cmp(a.streamPos, b.streamPos))

  var content = newJObject()
  for record in records:
    if not content.hasKey(record.eventId):
      content[record.eventId] = newJObject()
    if not content[record.eventId].hasKey(record.receiptType):
      content[record.eventId][record.receiptType] = newJObject()
    var userEntry = %*{"ts": record.ts}
    if record.threadId.len > 0:
      userEntry["thread_id"] = %record.threadId
    content[record.eventId][record.receiptType][record.userId] = userEntry

  result.add(%*{
    "type": "m.receipt",
    "content": content
  })

proc isValidPresenceValue(value: string): bool =
  value in ["online", "offline", "unavailable", "busy"]

proc presenceEventJson(state: ServerState; record: PresenceRecord): JsonNode =
  let user = state.users.getOrDefault(record.userId, UserProfile())
  var content = %*{
    "presence": record.presence,
    "currently_active": record.currentlyActive,
    "last_active_ago": max(0'i64, nowMs() - record.lastActiveTs),
  }
  if record.statusMsg.len > 0:
    content["status_msg"] = %record.statusMsg
  if user.displayName.len > 0:
    content["displayname"] = %user.displayName
  if user.avatarUrl.len > 0:
    content["avatar_url"] = %user.avatarUrl
  %*{
    "sender": record.userId,
    "type": "m.presence",
    "content": content,
  }

proc presenceResponseJson(record: PresenceRecord): JsonNode =
  result = %*{
    "presence": record.presence,
    "currently_active": record.currentlyActive,
  }
  if not record.currentlyActive:
    result["last_active_ago"] = %max(0'i64, nowMs() - record.lastActiveTs)
  if record.statusMsg.len > 0:
    result["status_msg"] = %record.statusMsg

proc setPresenceLocked(
    state: ServerState;
    userId, presenceValue, statusMsg: string
): PresenceRecord =
  inc state.streamPos
  result = PresenceRecord(
    userId: userId,
    presence: presenceValue,
    statusMsg: statusMsg,
    currentlyActive: presenceValue == "online",
    lastActiveTs: nowMs(),
    streamPos: state.streamPos,
  )
  state.presence[userId] = result

proc presenceEventsForSync(
    state: ServerState;
    viewerUserId: string;
    sincePos: int64;
    initial: bool
): JsonNode =
  result = newJArray()
  var records: seq[PresenceRecord] = @[]
  var visibleUsers = initHashSet[string]()
  visibleUsers.incl(viewerUserId)
  if viewerUserId in state.userJoinedRooms:
    for roomId in state.userJoinedRooms[viewerUserId]:
      if roomId notin state.rooms:
        continue
      for userId, membership in state.rooms[roomId].members:
        if membership == "join":
          visibleUsers.incl(userId)
  for _, record in state.presence:
    if record.userId in visibleUsers and (initial or record.streamPos > sincePos):
      records.add(record)
  records.sort(proc(a, b: PresenceRecord): int = cmp(a.streamPos, b.streamPos))
  for record in records:
    result.add(state.presenceEventJson(record))

proc setAccountDataLocked(
    state: ServerState;
    roomId, userId, eventType: string;
    content: JsonNode
): AccountDataRecord =
  inc state.streamPos
  result = AccountDataRecord(
    streamPos: state.streamPos,
    userId: userId,
    roomId: roomId,
    eventType: eventType,
    content: content,
  )
  state.accountData[accountDataKey(roomId, userId, eventType)] = result

proc getAccountDataLocked(
    state: ServerState;
    roomId, userId, eventType: string
): tuple[ok: bool, content: JsonNode] =
  let key = accountDataKey(roomId, userId, eventType)
  if key notin state.accountData:
    return (false, newJObject())
  let record = state.accountData[key]
  if isEmptyObjectJson(record.content):
    return (false, newJObject())
  (true, record.content)

proc roomTagsContentLocked(state: ServerState; roomId, userId: string): JsonNode =
  let existing = state.getAccountDataLocked(roomId, userId, "m.tag")
  if existing.ok and existing.content.kind == JObject:
    result = existing.content.copy()
  else:
    result = newJObject()
  if not result.hasKey("tags") or result["tags"].kind != JObject:
    result["tags"] = newJObject()

proc setRoomTagLocked(
    state: ServerState;
    roomId, userId, tag: string;
    tagContent: JsonNode
): AccountDataRecord =
  var content = state.roomTagsContentLocked(roomId, userId)
  content["tags"][tag] = tagContent
  state.setAccountDataLocked(roomId, userId, "m.tag", content)

proc deleteRoomTagLocked(
    state: ServerState;
    roomId, userId, tag: string
): AccountDataRecord =
  var content = state.roomTagsContentLocked(roomId, userId)
  content["tags"].delete(tag)
  state.setAccountDataLocked(roomId, userId, "m.tag", content)

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

proc safeHeaderFileName(fileName: string): string =
  result = ""
  for ch in fileName:
    if ch in {'\r', '\n', '"', '\\', ';'}:
      result.add('_')
    else:
      result.add(ch)

proc mediaContentDisposition(fileName: string): string =
  if fileName.len == 0:
    return "inline"
  "inline; filename=\"" & safeHeaderFileName(fileName) & "\""

proc loadStoredMedia(
    state: ServerState,
    mediaId: string
): tuple[ok: bool, body: string, contentType: string, fileName: string] =
  let mediaPath = mediaDataPath(state.statePath, mediaId)
  if not fileExists(mediaPath):
    return (false, "", "application/octet-stream", "")
  let meta = loadStoredMediaMeta(state, mediaId)
  (true, readFile(mediaPath), meta.contentType, meta.fileName)

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

proc ssoConfigString(cfg: FlatConfig; name, fallback: string): string =
  getConfigString(
    cfg,
    [
      "global.identity_provider." & name,
      "identity_provider." & name,
      "global." & name,
      name,
    ],
    fallback,
  )

proc ssoConfigBool(cfg: FlatConfig; name: string; fallback: bool): bool =
  getConfigBool(
    cfg,
    [
      "global.identity_provider." & name,
      "identity_provider." & name,
      "global." & name,
      name,
    ],
    fallback,
  )

proc ssoConfigInt(cfg: FlatConfig; name: string; fallback: int): int =
  getConfigInt(
    cfg,
    [
      "global.identity_provider." & name,
      "identity_provider." & name,
      "global." & name,
      name,
    ],
    fallback,
  )

proc ssoConfigStringArray(cfg: FlatConfig; name: string): seq[string] =
  getConfigStringArray(
    cfg,
    [
      "global.identity_provider." & name,
      "identity_provider." & name,
      "global." & name,
      name,
    ],
  )

proc ssoProviderFromConfig(cfg: FlatConfig): Option[SsoProvider] =
  let clientId = ssoConfigString(cfg, "client_id", "")
  let authorizationUrl = ssoConfigString(cfg, "authorization_url", "")
  if clientId.len == 0 or authorizationUrl.len == 0:
    return none(SsoProvider)
  var scope = ssoConfigStringArray(cfg, "scope")
  if scope.len == 0:
    scope = @["openid", "email", "profile"]
  let brand = ssoConfigString(cfg, "brand", clientId).toLowerAscii()
  let provider = SsoProvider(
    id: clientId,
    brand: brand,
    name: ssoConfigString(cfg, "name", if brand.len > 0: brand else: clientId),
    icon: ssoConfigString(cfg, "icon", ""),
    clientId: clientId,
    clientSecret: ssoConfigString(cfg, "client_secret", ""),
    authorizationUrl: authorizationUrl,
    tokenUrl: ssoConfigString(cfg, "token_url", ""),
    userInfoUrl: ssoConfigString(cfg, "userinfo_url", ""),
    callbackUrl: ssoConfigString(cfg, "callback_url", ""),
    scope: scope,
    defaultProvider: ssoConfigBool(cfg, "default", true),
    registration: ssoConfigBool(cfg, "registration", true),
    checkCookie: ssoConfigBool(cfg, "check_cookie", true),
    grantSessionTtlMs: max(1, ssoConfigInt(cfg, "grant_session_duration", 300)).int64 * 1000'i64,
  )
  some(provider)

proc providerMatches(provider: SsoProvider; id: string): bool =
  id.len == 0 or provider.id == id or provider.clientId == id or
    (provider.brand.len > 0 and provider.brand.cmpIgnoreCase(id) == 0)

proc ssoProviderPayload(provider: SsoProvider): JsonNode =
  result = %*{
    "id": provider.id,
    "name": provider.name,
    "brand": provider.brand,
  }
  if provider.icon.len > 0:
    result["icon"] = %provider.icon

proc loginTypesResponseWithSso(cfg: FlatConfig): JsonNode =
  result = loginTypesResponse()
  let providerOpt = ssoProviderFromConfig(cfg)
  if providerOpt.isNone:
    return
  var ssoFlow = %*{
    "type": "m.login.sso",
    "identity_providers": [ssoProviderPayload(providerOpt.get())],
  }
  if getConfigBool(cfg, ["sso_aware_preferred", "global.sso_aware_preferred", "oidc_aware_preferred"], false):
    ssoFlow["org.matrix.msc3824.oauth_aware"] = %true
  result["flows"].add(ssoFlow)

proc appendQueryParam(url, key, value: string): string =
  let sep =
    if url.contains("?"):
      if url.endsWith("?") or url.endsWith("&"): "" else: "&"
    else:
      "?"
  url & sep & encodeUrl(key) & "=" & encodeUrl(value)

proc ssoLoginPathParts(path: string): tuple[ok: bool, providerId: string] =
  const Prefixes = [
    "/_matrix/client/v3/login/sso/redirect",
    "/_matrix/client/r0/login/sso/redirect",
  ]
  for prefix in Prefixes:
    if path == prefix:
      return (true, "")
    if path.startsWith(prefix & "/"):
      let providerId = decodeUrl(path[(prefix.len + 1) .. ^1])
      return (providerId.len > 0, providerId)
  (false, "")

proc ssoCallbackProviderId(path: string): string =
  const Prefixes = [
    "/_matrix/client/unstable/login/sso/callback/",
    "/_matrix/client/v3/login/sso/callback/",
    "/_matrix/client/r0/login/sso/callback/",
  ]
  for prefix in Prefixes:
    if path.startsWith(prefix):
      return decodeUrl(path[prefix.len .. ^1])
  ""

proc ssoAuthorizationLocation(provider: SsoProvider; session: SsoSessionRecord): string =
  result = provider.authorizationUrl
  result = appendQueryParam(result, "client_id", provider.clientId)
  result = appendQueryParam(result, "state", session.sessionId)
  result = appendQueryParam(result, "nonce", session.nonce)
  result = appendQueryParam(result, "scope", provider.scope.join(" "))
  result = appendQueryParam(result, "response_type", "code")
  result = appendQueryParam(result, "access_type", "online")
  result = appendQueryParam(result, "code_challenge_method", "plain")
  result = appendQueryParam(result, "code_challenge", session.codeVerifier)
  if provider.callbackUrl.len > 0:
    result = appendQueryParam(result, "redirect_uri", provider.callbackUrl)

proc ssoCookie(session: SsoSessionRecord; provider: SsoProvider): string =
  let maxAge = max(1'i64, provider.grantSessionTtlMs div 1000)
  "tuwunel_grant_session=client_id=" & encodeUrl(provider.clientId) &
    "&state=" & encodeUrl(session.sessionId) &
    "&nonce=" & encodeUrl(session.nonce) &
    "&redirect_uri=" & encodeUrl(session.redirectUrl) &
    "; Max-Age=" & $maxAge &
    "; Path=/; SameSite=None; Secure; HttpOnly"

proc createSsoSessionLocked(
    state: ServerState;
    provider: SsoProvider;
    redirectUrl, loginToken: string
): SsoSessionRecord =
  var userId = ""
  if loginToken.len > 0 and loginToken in state.loginTokens:
    let record = state.loginTokens[loginToken]
    if record.expiresAtMs > nowMs() and record.userId in state.users:
      userId = record.userId
    elif record.expiresAtMs <= nowMs():
      state.loginTokens.del(loginToken)
  result = SsoSessionRecord(
    sessionId: randomString("sso_", 32),
    idpId: provider.id,
    redirectUrl: redirectUrl,
    codeVerifier: randomString("verifier_", 48),
    nonce: randomString("nonce_", 24),
    userId: userId,
    expiresAtMs: nowMs() + provider.grantSessionTtlMs,
  )
  state.ssoSessions[result.sessionId] = result

proc userIdFromSsoClaims(state: ServerState; provider: SsoProvider; claims: JsonNode): string =
  if claims.kind == JObject:
    for key in ["preferred_username", "username", "login", "email", "name", "sub"]:
      let raw = claims{key}.getStr("")
      if raw.len == 0:
        continue
      var local = raw
      let atPos = local.find('@')
      if atPos > 0:
        local = local[0 ..< atPos]
      local = local.toLowerAscii()
      var cleaned = ""
      for ch in local:
        if ch.isAlphaNumeric or ch in {'.', '_', '-', '='}:
          cleaned.add(ch)
      if cleaned.len > 0:
        return "@" & cleaned & ":" & state.serverName
  "@" & provider.brand & "_" & randomString("", 8).toLowerAscii() & ":" & state.serverName

proc ensureSsoUserLocked(
    state: ServerState;
    provider: SsoProvider;
    session: SsoSessionRecord;
    claims: JsonNode
): tuple[ok: bool, userId: string, errcode: string, message: string] =
  var userId = session.userId
  if userId.len == 0:
    userId = state.userIdFromSsoClaims(provider, claims)
  if userId in state.users:
    return (true, userId, "", "")
  if not provider.registration:
    return (false, "", "M_FORBIDDEN", "Registration from this provider is disabled.")
  let local = localpartFromUserId(userId)
  let displayName =
    if claims.kind == JObject:
      claims{"name"}.getStr(claims{"preferred_username"}.getStr(local))
    else:
      local
  state.users[userId] = UserProfile(
    userId: userId,
    username: local,
    password: "",
    displayName: displayName,
    avatarUrl: if claims.kind == JObject: claims{"picture"}.getStr(claims{"avatar_url"}.getStr("")) else: "",
    blurhash: "",
    timezone: "",
    profileFields: initTable[string, JsonNode](),
  )
  if local.len > 0 and local notin state.usersByName:
    state.usersByName[local] = userId
  (true, userId, "", "")

{.push warning[Uninit]: off.}
proc requestSsoUserInfo(
    provider: SsoProvider;
    session: SsoSessionRecord;
    code: string
): Future[tuple[ok: bool, payload: JsonNode, errcode: string, message: string]] {.async.} =
  if provider.tokenUrl.len == 0 or provider.userInfoUrl.len == 0:
    return (false, newJObject(), "M_NOT_IMPLEMENTED", "SSO token and userinfo URLs are not configured.")
  let tokenBody =
    "grant_type=authorization_code" &
    "&code=" & encodeUrl(code) &
    "&client_id=" & encodeUrl(provider.clientId) &
    "&code_verifier=" & encodeUrl(session.codeVerifier) &
    (if provider.clientSecret.len > 0: "&client_secret=" & encodeUrl(provider.clientSecret) else: "") &
    (if provider.callbackUrl.len > 0: "&redirect_uri=" & encodeUrl(provider.callbackUrl) else: "")
  try:
    let client = newAsyncHttpClient()
    defer:
      client.close()
    client.headers = newHttpHeaders({"Content-Type": "application/x-www-form-urlencoded"})
    let tokenResp = await client.request(provider.tokenUrl, httpMethod = HttpPost, body = tokenBody)
    if ord(tokenResp.code) < 200 or ord(tokenResp.code) >= 300:
      return (false, newJObject(), "M_FORBIDDEN", "SSO token exchange failed.")
    let tokenJson = parseJson(await tokenResp.body)
    let accessToken = tokenJson{"access_token"}.getStr("")
    if accessToken.len == 0:
      return (false, newJObject(), "M_FORBIDDEN", "SSO token response had no access token.")
    let userClient = newAsyncHttpClient()
    defer:
      userClient.close()
    userClient.headers = newHttpHeaders({"Authorization": "Bearer " & accessToken})
    let userResp = await userClient.request(provider.userInfoUrl, httpMethod = HttpGet)
    if ord(userResp.code) < 200 or ord(userResp.code) >= 300:
      return (false, newJObject(), "M_FORBIDDEN", "SSO userinfo request failed.")
    let userJson = parseJson(await userResp.body)
    (true, userJson, "", "")
  except CatchableError as e:
    (false, newJObject(), "M_FORBIDDEN", "SSO callback failed: " & e.msg)
{.pop.}

proc eventToJson(ev: MatrixEventRecord): JsonNode =
  result = %*{
    "event_id": ev.eventId,
    "room_id": ev.roomId,
    "sender": ev.sender,
    "type": ev.eventType,
    "origin_server_ts": ev.originServerTs,
    "content": ev.content,
  }
  if isStateEventForStorage(ev.eventType, ev.stateKey):
    result["state_key"] = %ev.stateKey
  if ev.redacts.len > 0:
    result["redacts"] = %ev.redacts

proc stateEventResponsePayload(ev: MatrixEventRecord; formatValue: string): JsonNode =
  if formatValue.strip().toLowerAscii() == "event":
    return ev.eventToJson()
  ev.content

proc deviceToJson(device: DeviceRecord): JsonNode =
  result = %*{"device_id": device.deviceId}
  if device.displayName.len > 0:
    result["display_name"] = %device.displayName
  if device.lastSeenIp.len > 0:
    result["last_seen_ip"] = %device.lastSeenIp
  if device.lastSeenTs > 0:
    result["last_seen_ts"] = %device.lastSeenTs

proc upsertDeviceLocked(
    state: ServerState;
    userId, deviceId, displayName: string;
    lastSeenIp = ""
): DeviceRecord =
  let key = deviceKey(userId, deviceId)
  if key in state.devices:
    result = state.devices[key]
    if displayName.len > 0:
      result.displayName = displayName
  else:
    result = DeviceRecord(
      userId: userId,
      deviceId: deviceId,
      displayName: displayName,
      lastSeenIp: "",
      lastSeenTs: 0,
    )
  if lastSeenIp.len > 0:
    result.lastSeenIp = lastSeenIp
  result.lastSeenTs = nowMs()
  state.devices[key] = result

proc listDevicesPayloadLocked(state: ServerState; userId: string): JsonNode =
  var devices: seq[DeviceRecord] = @[]
  for _, device in state.devices:
    if device.userId == userId:
      devices.add(device)
  devices.sort(proc(a, b: DeviceRecord): int = cmp(a.deviceId, b.deviceId))
  var arr = newJArray()
  for device in devices:
    arr.add(device.deviceToJson())
  %*{"devices": arr}

proc removeDeviceLocked(state: ServerState; userId, deviceId: string) =
  state.devices.del(deviceKey(userId, deviceId))
  var keptTokens: seq[string] = @[]
  if userId in state.userTokens:
    for token in state.userTokens[userId]:
      if token in state.tokens and state.tokens[token].deviceId == deviceId:
        state.tokens.del(token)
      else:
        keptTokens.add(token)
    if keptTokens.len == 0:
      state.userTokens.del(userId)
    else:
      state.userTokens[userId] = keptTokens
  var staleRefresh: seq[string] = @[]
  for token, record in state.refreshTokens:
    if record.userId == userId and record.deviceId == deviceId:
      staleRefresh.add(token)
  for token in staleRefresh:
    state.refreshTokens.del(token)

proc toPersistentJson(state: ServerState): JsonNode =
  var root = newJObject()
  root["stream_pos"] = %state.streamPos
  root["delivery_counter"] = %state.deliveryCounter
  root["room_counter"] = %state.roomCounter

  var users = newJArray()
  for _, user in state.users:
    var profileFields = newJObject()
    for key, value in user.profileFields:
      profileFields[key] = value
    users.add(%*{
      "user_id": user.userId,
      "username": user.username,
      "password": user.password,
      "display_name": user.displayName,
      "avatar_url": user.avatarUrl,
      "blurhash": user.blurhash,
      "timezone": user.timezone,
      "profile_fields": profileFields
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

  var refreshTokens = newJArray()
  for _, record in state.refreshTokens:
    if record.expiresAtMs <= nowMs():
      continue
    refreshTokens.add(%*{
      "refresh_token": record.refreshToken,
      "user_id": record.userId,
      "device_id": record.deviceId,
      "expires_at_ms": record.expiresAtMs,
    })
  root["refresh_tokens"] = refreshTokens

  var ssoSessions = newJArray()
  for _, record in state.ssoSessions:
    if record.expiresAtMs <= nowMs():
      continue
    ssoSessions.add(%*{
      "session_id": record.sessionId,
      "idp_id": record.idpId,
      "redirect_url": record.redirectUrl,
      "code_verifier": record.codeVerifier,
      "nonce": record.nonce,
      "user_id": record.userId,
      "expires_at_ms": record.expiresAtMs,
    })
  root["sso_sessions"] = ssoSessions

  var openIdTokens = newJArray()
  for _, record in state.openIdTokens:
    if record.expiresAtMs <= nowMs():
      continue
    openIdTokens.add(%*{
      "access_token": record.accessToken,
      "user_id": record.userId,
      "expires_at_ms": record.expiresAtMs,
      "stream_pos": record.streamPos,
    })
  root["openid_tokens"] = openIdTokens

  var devices = newJArray()
  for _, device in state.devices:
    devices.add(%*{
      "user_id": device.userId,
      "device_id": device.deviceId,
      "display_name": device.displayName,
      "last_seen_ip": device.lastSeenIp,
      "last_seen_ts": device.lastSeenTs,
    })
  root["devices"] = devices

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

  var accountData = newJArray()
  for _, record in state.accountData:
    accountData.add(%*{
      "stream_pos": record.streamPos,
      "user_id": record.userId,
      "room_id": record.roomId,
      "type": record.eventType,
      "content": record.content,
    })
  root["account_data"] = accountData

  var filters = newJArray()
  for key, filter in state.filters:
    let parts = key.split("\x1f")
    if parts.len != 2:
      continue
    filters.add(%*{
      "user_id": parts[0],
      "filter_id": parts[1],
      "filter": filter,
    })
  root["filters"] = filters

  var pushers = newJArray()
  for key, pusher in state.pushers:
    let parts = key.split("\x1f")
    if parts.len != 3:
      continue
    pushers.add(%*{
      "user_id": parts[0],
      "app_id": parts[1],
      "pushkey": parts[2],
      "pusher": pusher,
    })
  root["pushers"] = pushers

  var pushRules = newJArray()
  for key, rule in state.pushRules:
    let parts = key.split("\x1f")
    if parts.len != 4:
      continue
    pushRules.add(%*{
      "user_id": parts[0],
      "scope": parts[1],
      "kind": parts[2],
      "rule_id": parts[3],
      "rule": rule,
    })
  root["push_rules"] = pushRules

  var backupVersions = newJArray()
  for _, record in state.backupVersions:
    backupVersions.add(%*{
      "user_id": record.userId,
      "version": record.version,
      "algorithm": record.algorithm,
      "auth_data": record.authData,
      "etag": record.etag,
      "stream_pos": record.streamPos,
    })
  root["backup_counter"] = %state.backupCounter
  root["backup_versions"] = backupVersions

  var backupSessions = newJArray()
  for _, record in state.backupSessions:
    backupSessions.add(%*{
      "user_id": record.userId,
      "version": record.version,
      "room_id": record.roomId,
      "session_id": record.sessionId,
      "session_data": record.sessionData,
      "stream_pos": record.streamPos,
    })
  root["backup_sessions"] = backupSessions

  var deviceKeys = newJArray()
  for _, record in state.deviceKeys:
    deviceKeys.add(%*{
      "user_id": record.userId,
      "device_id": record.deviceId,
      "key_data": record.keyData,
      "stream_pos": record.streamPos,
    })
  root["device_keys"] = deviceKeys

  var oneTimeKeys = newJArray()
  for _, record in state.oneTimeKeys:
    oneTimeKeys.add(%*{
      "user_id": record.userId,
      "device_id": record.deviceId,
      "algorithm": record.algorithm,
      "key_id": record.keyId,
      "key_data": record.keyData,
      "stream_pos": record.streamPos,
    })
  root["one_time_keys"] = oneTimeKeys

  var fallbackKeys = newJArray()
  for _, record in state.fallbackKeys:
    fallbackKeys.add(%*{
      "user_id": record.userId,
      "device_id": record.deviceId,
      "algorithm": record.algorithm,
      "key_id": record.keyId,
      "key_data": record.keyData,
      "used": record.used,
      "stream_pos": record.streamPos,
    })
  root["fallback_keys"] = fallbackKeys

  var dehydratedDevices = newJArray()
  for _, record in state.dehydratedDevices:
    dehydratedDevices.add(%*{
      "user_id": record.userId,
      "device_id": record.deviceId,
      "device_data": record.deviceData,
      "stream_pos": record.streamPos,
    })
  root["dehydrated_devices"] = dehydratedDevices

  var crossSigningKeys = newJArray()
  for _, record in state.crossSigningKeys:
    crossSigningKeys.add(%*{
      "user_id": record.userId,
      "key_type": record.keyType,
      "key_data": record.keyData,
      "stream_pos": record.streamPos,
    })
  root["cross_signing_keys"] = crossSigningKeys

  var toDeviceEvents = newJArray()
  for _, record in state.toDeviceEvents:
    toDeviceEvents.add(%*{
      "target_user_id": record.targetUserId,
      "target_device_id": record.targetDeviceId,
      "sender": record.sender,
      "type": record.eventType,
      "txn_id": record.txnId,
      "content": record.content,
      "stream_pos": record.streamPos,
    })
  root["to_device_events"] = toDeviceEvents

  var toDeviceTxnIds = newJArray()
  for txnId in state.toDeviceTxnIds:
    toDeviceTxnIds.add(%txnId)
  root["to_device_txn_ids"] = toDeviceTxnIds

  var receipts = newJArray()
  for _, record in state.receipts:
    receipts.add(%*{
      "stream_pos": record.streamPos,
      "room_id": record.roomId,
      "event_id": record.eventId,
      "receipt_type": record.receiptType,
      "user_id": record.userId,
      "thread_id": record.threadId,
      "ts": record.ts,
    })
  root["receipts"] = receipts

  var presence = newJArray()
  for _, record in state.presence:
    presence.add(%*{
      "stream_pos": record.streamPos,
      "user_id": record.userId,
      "presence": record.presence,
      "status_msg": record.statusMsg,
      "currently_active": record.currentlyActive,
      "last_active_ts": record.lastActiveTs,
    })
  root["presence"] = presence

  var reports = newJArray()
  for record in state.reports:
    reports.add(%*{
      "report_id": record.reportId,
      "reporter_user_id": record.reporterUserId,
      "room_id": record.roomId,
      "event_id": record.eventId,
      "reason": record.reason,
      "score": record.score,
      "ts": record.ts,
      "stream_pos": record.streamPos,
    })
  root["reports"] = reports
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
    refreshTokens: Table[string, RefreshTokenRecord],
    ssoSessions: Table[string, SsoSessionRecord],
    devices: Table[string, DeviceRecord],
    rooms: Table[string, RoomData],
    accountData: Table[string, AccountDataRecord],
    filters: Table[string, JsonNode],
    pushers: Table[string, JsonNode],
    pushRules: Table[string, JsonNode],
    backupCounter: int64,
    backupVersions: Table[string, BackupVersionRecord],
    backupSessions: Table[string, BackupSessionRecord],
    deviceKeys: Table[string, DeviceKeyRecord],
    oneTimeKeys: Table[string, OneTimeKeyRecord],
    fallbackKeys: Table[string, FallbackKeyRecord],
    dehydratedDevices: Table[string, DehydratedDeviceRecord],
    crossSigningKeys: Table[string, CrossSigningKeyRecord],
    toDeviceEvents: Table[string, ToDeviceEventRecord],
    toDeviceTxnIds: HashSet[string],
    openIdTokens: Table[string, OpenIdTokenRecord],
    receipts: Table[string, ReceiptRecord],
    presence: Table[string, PresenceRecord],
    reports: seq[ReportRecord],
    streamPos: int64,
    deliveryCounter: int64,
    roomCounter: int64
] =
  result = (
    usersByName: initTable[string, string](),
    users: initTable[string, UserProfile](),
    tokens: initTable[string, AccessSession](),
    userTokens: initTable[string, seq[string]](),
    refreshTokens: initTable[string, RefreshTokenRecord](),
    ssoSessions: initTable[string, SsoSessionRecord](),
    devices: initTable[string, DeviceRecord](),
    rooms: initTable[string, RoomData](),
    accountData: initTable[string, AccountDataRecord](),
    filters: initTable[string, JsonNode](),
    pushers: initTable[string, JsonNode](),
    pushRules: initTable[string, JsonNode](),
    backupCounter: 0'i64,
    backupVersions: initTable[string, BackupVersionRecord](),
    backupSessions: initTable[string, BackupSessionRecord](),
    deviceKeys: initTable[string, DeviceKeyRecord](),
    oneTimeKeys: initTable[string, OneTimeKeyRecord](),
    fallbackKeys: initTable[string, FallbackKeyRecord](),
    dehydratedDevices: initTable[string, DehydratedDeviceRecord](),
    crossSigningKeys: initTable[string, CrossSigningKeyRecord](),
    toDeviceEvents: initTable[string, ToDeviceEventRecord](),
    toDeviceTxnIds: initHashSet[string](),
    openIdTokens: initTable[string, OpenIdTokenRecord](),
    receipts: initTable[string, ReceiptRecord](),
    presence: initTable[string, PresenceRecord](),
    reports: @[],
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
    result.backupCounter = root{"backup_counter"}.getInt(0).int64

    if root.hasKey("users") and root["users"].kind == JArray:
      for node in root["users"]:
        if node.kind != JObject:
          continue
        let userId = node{"user_id"}.getStr("")
        let username = node{"username"}.getStr("")
        if userId.len == 0:
          continue
        var user = UserProfile(
          userId: userId,
          username: username,
          password: node{"password"}.getStr(""),
          displayName: node{"display_name"}.getStr(""),
          avatarUrl: node{"avatar_url"}.getStr(""),
          blurhash: node{"blurhash"}.getStr(""),
          timezone: node{"timezone"}.getStr(""),
          profileFields: initTable[string, JsonNode]()
        )
        if node.hasKey("profile_fields") and node["profile_fields"].kind == JObject:
          for key, value in node["profile_fields"]:
            if key.len > 0:
              user.profileFields[key] = value
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

    if root.hasKey("refresh_tokens") and root["refresh_tokens"].kind == JArray:
      for node in root["refresh_tokens"]:
        if node.kind != JObject:
          continue
        let refreshToken = node{"refresh_token"}.getStr("")
        let userId = node{"user_id"}.getStr("")
        let deviceId = node{"device_id"}.getStr("")
        let expiresAtMs = node{"expires_at_ms"}.getInt(0).int64
        if refreshToken.len == 0 or userId.len == 0 or deviceId.len == 0 or expiresAtMs <= nowMs():
          continue
        result.refreshTokens[refreshToken] = RefreshTokenRecord(
          refreshToken: refreshToken,
          userId: userId,
          deviceId: deviceId,
          expiresAtMs: expiresAtMs,
        )

    if root.hasKey("sso_sessions") and root["sso_sessions"].kind == JArray:
      for node in root["sso_sessions"]:
        if node.kind != JObject:
          continue
        let sessionId = node{"session_id"}.getStr("")
        let idpId = node{"idp_id"}.getStr("")
        let redirectUrl = node{"redirect_url"}.getStr("")
        let expiresAtMs = node{"expires_at_ms"}.getInt(0).int64
        if sessionId.len == 0 or idpId.len == 0 or redirectUrl.len == 0 or expiresAtMs <= nowMs():
          continue
        result.ssoSessions[sessionId] = SsoSessionRecord(
          sessionId: sessionId,
          idpId: idpId,
          redirectUrl: redirectUrl,
          codeVerifier: node{"code_verifier"}.getStr(""),
          nonce: node{"nonce"}.getStr(""),
          userId: node{"user_id"}.getStr(""),
          expiresAtMs: expiresAtMs,
        )

    if root.hasKey("openid_tokens") and root["openid_tokens"].kind == JArray:
      for node in root["openid_tokens"]:
        if node.kind != JObject:
          continue
        let token = node{"access_token"}.getStr("")
        let userId = node{"user_id"}.getStr("")
        let expiresAtMs = node{"expires_at_ms"}.getInt(0).int64
        if token.len == 0 or userId.len == 0 or expiresAtMs <= nowMs():
          continue
        let record = OpenIdTokenRecord(
          accessToken: token,
          userId: userId,
          expiresAtMs: expiresAtMs,
          streamPos: node{"stream_pos"}.getInt(0).int64,
        )
        result.openIdTokens[token] = record
        if record.streamPos > result.streamPos:
          result.streamPos = record.streamPos

    if root.hasKey("devices") and root["devices"].kind == JArray:
      for node in root["devices"]:
        if node.kind != JObject:
          continue
        let userId = node{"user_id"}.getStr("")
        let deviceId = node{"device_id"}.getStr("")
        if userId.len == 0 or deviceId.len == 0:
          continue
        let device = DeviceRecord(
          userId: userId,
          deviceId: deviceId,
          displayName: node{"display_name"}.getStr(""),
          lastSeenIp: node{"last_seen_ip"}.getStr(""),
          lastSeenTs: node{"last_seen_ts"}.getInt(0).int64,
        )
        result.devices[deviceKey(userId, deviceId)] = device

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

    if root.hasKey("account_data") and root["account_data"].kind == JArray:
      for node in root["account_data"]:
        if node.kind != JObject:
          continue
        let userId = node{"user_id"}.getStr("")
        let eventType = node{"type"}.getStr("")
        if userId.len == 0 or eventType.len == 0:
          continue
        let record = AccountDataRecord(
          streamPos: node{"stream_pos"}.getInt(0).int64,
          userId: userId,
          roomId: node{"room_id"}.getStr(""),
          eventType: eventType,
          content: if node.hasKey("content"): node["content"] else: newJObject()
        )
        result.accountData[accountDataKey(record.roomId, record.userId, record.eventType)] = record
        if record.streamPos > result.streamPos:
          result.streamPos = record.streamPos

    if root.hasKey("filters") and root["filters"].kind == JArray:
      for node in root["filters"]:
        if node.kind != JObject:
          continue
        let userId = node{"user_id"}.getStr("")
        let filterId = node{"filter_id"}.getStr("")
        if userId.len == 0 or filterId.len == 0:
          continue
        result.filters[filterKey(userId, filterId)] =
          if node.hasKey("filter"): node["filter"] else: newJObject()

    if root.hasKey("pushers") and root["pushers"].kind == JArray:
      for node in root["pushers"]:
        if node.kind != JObject:
          continue
        let userId = node{"user_id"}.getStr("")
        let appId = node{"app_id"}.getStr("")
        let pushKeyValue = node{"pushkey"}.getStr("")
        if userId.len == 0 or appId.len == 0 or pushKeyValue.len == 0:
          continue
        result.pushers[pusherKey(userId, appId, pushKeyValue)] =
          if node.hasKey("pusher"): node["pusher"] else: newJObject()

    if root.hasKey("push_rules") and root["push_rules"].kind == JArray:
      for node in root["push_rules"]:
        if node.kind != JObject:
          continue
        let userId = node{"user_id"}.getStr("")
        let scope = node{"scope"}.getStr("")
        let kind = node{"kind"}.getStr("")
        let ruleId = node{"rule_id"}.getStr("")
        if userId.len == 0 or scope.len == 0 or kind.len == 0 or ruleId.len == 0:
          continue
        result.pushRules[pushRuleKey(userId, scope, kind, ruleId)] =
          if node.hasKey("rule"): node["rule"] else: newJObject()

    if root.hasKey("backup_versions") and root["backup_versions"].kind == JArray:
      for node in root["backup_versions"]:
        if node.kind != JObject:
          continue
        let userId = node{"user_id"}.getStr("")
        let version = node{"version"}.getStr("")
        if userId.len == 0 or version.len == 0:
          continue
        let record = BackupVersionRecord(
          userId: userId,
          version: version,
          algorithm: node{"algorithm"}.getStr("m.megolm_backup.v1.curve25519-aes-sha2"),
          authData: if node.hasKey("auth_data"): node["auth_data"] else: newJObject(),
          etag: node{"etag"}.getStr(""),
          streamPos: node{"stream_pos"}.getInt(0).int64,
        )
        result.backupVersions[backupVersionKey(userId, version)] = record
        if record.streamPos > result.streamPos:
          result.streamPos = record.streamPos
        try:
          result.backupCounter = max(result.backupCounter, parseInt(version).int64)
        except ValueError:
          discard

    if root.hasKey("backup_sessions") and root["backup_sessions"].kind == JArray:
      for node in root["backup_sessions"]:
        if node.kind != JObject:
          continue
        let userId = node{"user_id"}.getStr("")
        let version = node{"version"}.getStr("")
        let roomId = node{"room_id"}.getStr("")
        let sessionId = node{"session_id"}.getStr("")
        if userId.len == 0 or version.len == 0 or roomId.len == 0 or sessionId.len == 0:
          continue
        let record = BackupSessionRecord(
          userId: userId,
          version: version,
          roomId: roomId,
          sessionId: sessionId,
          sessionData: if node.hasKey("session_data"): node["session_data"] else: newJObject(),
          streamPos: node{"stream_pos"}.getInt(0).int64,
        )
        result.backupSessions[backupSessionKey(userId, version, roomId, sessionId)] = record
        if record.streamPos > result.streamPos:
          result.streamPos = record.streamPos

    if root.hasKey("device_keys") and root["device_keys"].kind == JArray:
      for node in root["device_keys"]:
        if node.kind != JObject:
          continue
        let userId = node{"user_id"}.getStr("")
        let deviceId = node{"device_id"}.getStr("")
        if userId.len == 0 or deviceId.len == 0:
          continue
        let record = DeviceKeyRecord(
          userId: userId,
          deviceId: deviceId,
          keyData: if node.hasKey("key_data"): node["key_data"] else: newJObject(),
          streamPos: node{"stream_pos"}.getInt(0).int64,
        )
        result.deviceKeys[deviceKey(userId, deviceId)] = record
        if record.streamPos > result.streamPos:
          result.streamPos = record.streamPos

    if root.hasKey("one_time_keys") and root["one_time_keys"].kind == JArray:
      for node in root["one_time_keys"]:
        if node.kind != JObject:
          continue
        let userId = node{"user_id"}.getStr("")
        let deviceId = node{"device_id"}.getStr("")
        let algorithm = node{"algorithm"}.getStr("")
        let keyId = node{"key_id"}.getStr("")
        if userId.len == 0 or deviceId.len == 0 or algorithm.len == 0 or keyId.len == 0:
          continue
        let record = OneTimeKeyRecord(
          userId: userId,
          deviceId: deviceId,
          algorithm: algorithm,
          keyId: keyId,
          keyData: if node.hasKey("key_data"): node["key_data"] else: newJObject(),
          streamPos: node{"stream_pos"}.getInt(0).int64,
        )
        result.oneTimeKeys[oneTimeKeyStoreKey(userId, deviceId, algorithm, keyId)] = record
        if record.streamPos > result.streamPos:
          result.streamPos = record.streamPos

    if root.hasKey("fallback_keys") and root["fallback_keys"].kind == JArray:
      for node in root["fallback_keys"]:
        if node.kind != JObject:
          continue
        let userId = node{"user_id"}.getStr("")
        let deviceId = node{"device_id"}.getStr("")
        let algorithm = node{"algorithm"}.getStr("")
        let keyId = node{"key_id"}.getStr("")
        if userId.len == 0 or deviceId.len == 0 or algorithm.len == 0 or keyId.len == 0:
          continue
        let record = FallbackKeyRecord(
          userId: userId,
          deviceId: deviceId,
          algorithm: algorithm,
          keyId: keyId,
          keyData: if node.hasKey("key_data"): node["key_data"] else: newJObject(),
          used: node{"used"}.getBool(false),
          streamPos: node{"stream_pos"}.getInt(0).int64,
        )
        result.fallbackKeys[oneTimeKeyStoreKey(userId, deviceId, algorithm, keyId)] = record
        if record.streamPos > result.streamPos:
          result.streamPos = record.streamPos

    if root.hasKey("dehydrated_devices") and root["dehydrated_devices"].kind == JArray:
      for node in root["dehydrated_devices"]:
        if node.kind != JObject:
          continue
        let userId = node{"user_id"}.getStr("")
        let deviceId = node{"device_id"}.getStr("")
        if userId.len == 0 or deviceId.len == 0:
          continue
        let record = DehydratedDeviceRecord(
          userId: userId,
          deviceId: deviceId,
          deviceData: if node.hasKey("device_data"): node["device_data"] else: newJObject(),
          streamPos: node{"stream_pos"}.getInt(0).int64,
        )
        result.dehydratedDevices[userId] = record
        if record.streamPos > result.streamPos:
          result.streamPos = record.streamPos

    if root.hasKey("cross_signing_keys") and root["cross_signing_keys"].kind == JArray:
      for node in root["cross_signing_keys"]:
        if node.kind != JObject:
          continue
        let userId = node{"user_id"}.getStr("")
        let keyType = node{"key_type"}.getStr("")
        if userId.len == 0 or keyType.len == 0:
          continue
        let record = CrossSigningKeyRecord(
          userId: userId,
          keyType: keyType,
          keyData: if node.hasKey("key_data"): node["key_data"] else: newJObject(),
          streamPos: node{"stream_pos"}.getInt(0).int64,
        )
        result.crossSigningKeys[crossSigningKey(userId, keyType)] = record
        if record.streamPos > result.streamPos:
          result.streamPos = record.streamPos

    if root.hasKey("to_device_events") and root["to_device_events"].kind == JArray:
      for node in root["to_device_events"]:
        if node.kind != JObject:
          continue
        let targetUserId = node{"target_user_id"}.getStr("")
        let targetDeviceId = node{"target_device_id"}.getStr("")
        let eventType = node{"type"}.getStr("")
        let streamPos = node{"stream_pos"}.getInt(0).int64
        if targetUserId.len == 0 or targetDeviceId.len == 0 or eventType.len == 0 or streamPos <= 0:
          continue
        let record = ToDeviceEventRecord(
          targetUserId: targetUserId,
          targetDeviceId: targetDeviceId,
          sender: node{"sender"}.getStr(""),
          eventType: eventType,
          txnId: node{"txn_id"}.getStr(""),
          content: if node.hasKey("content"): node["content"] else: newJObject(),
          streamPos: streamPos,
        )
        result.toDeviceEvents[toDeviceEventKey(targetUserId, targetDeviceId, streamPos)] = record
        if record.streamPos > result.streamPos:
          result.streamPos = record.streamPos

    if root.hasKey("to_device_txn_ids") and root["to_device_txn_ids"].kind == JArray:
      for node in root["to_device_txn_ids"]:
        let txnId = node.getStr("")
        if txnId.len > 0:
          result.toDeviceTxnIds.incl(txnId)

    if root.hasKey("receipts") and root["receipts"].kind == JArray:
      for node in root["receipts"]:
        if node.kind != JObject:
          continue
        let roomId = node{"room_id"}.getStr("")
        let eventId = node{"event_id"}.getStr("")
        let receiptType = node{"receipt_type"}.getStr("")
        let userId = node{"user_id"}.getStr("")
        if roomId.len == 0 or eventId.len == 0 or receiptType.len == 0 or userId.len == 0:
          continue
        let record = ReceiptRecord(
          roomId: roomId,
          eventId: eventId,
          receiptType: receiptType,
          userId: userId,
          threadId: node{"thread_id"}.getStr(""),
          ts: node{"ts"}.getInt(0).int64,
          streamPos: node{"stream_pos"}.getInt(0).int64,
        )
        result.receipts[receiptKey(record.roomId, record.eventId, record.receiptType, record.userId, record.threadId)] = record
        if record.streamPos > result.streamPos:
          result.streamPos = record.streamPos

    if root.hasKey("presence") and root["presence"].kind == JArray:
      for node in root["presence"]:
        if node.kind != JObject:
          continue
        let userId = node{"user_id"}.getStr("")
        let presenceValue = node{"presence"}.getStr("")
        if userId.len == 0 or not isValidPresenceValue(presenceValue):
          continue
        let record = PresenceRecord(
          userId: userId,
          presence: presenceValue,
          statusMsg: node{"status_msg"}.getStr(""),
          currentlyActive: node{"currently_active"}.getBool(presenceValue == "online"),
          lastActiveTs: node{"last_active_ts"}.getInt(0).int64,
          streamPos: node{"stream_pos"}.getInt(0).int64,
        )
        result.presence[userId] = record
        if record.streamPos > result.streamPos:
          result.streamPos = record.streamPos

    if root.hasKey("reports") and root["reports"].kind == JArray:
      for node in root["reports"]:
        if node.kind != JObject:
          continue
        let reportId = node{"report_id"}.getStr("")
        let reporterUserId = node{"reporter_user_id"}.getStr("")
        let roomId = node{"room_id"}.getStr("")
        if reportId.len == 0 or reporterUserId.len == 0 or roomId.len == 0:
          continue
        let record = ReportRecord(
          reportId: reportId,
          reporterUserId: reporterUserId,
          roomId: roomId,
          eventId: node{"event_id"}.getStr(""),
          reason: node{"reason"}.getStr(""),
          score: node{"score"}.getInt(0),
          ts: node{"ts"}.getInt(0).int64,
          streamPos: node{"stream_pos"}.getInt(0).int64,
        )
        result.reports.add(record)
        if record.streamPos > result.streamPos:
          result.streamPos = record.streamPos
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
): tuple[code: HttpCode, payload: JsonNode, rejectionReason: string] =
  let normalizedId = registrationId.strip()
  if normalizedId.len == 0:
    return (Http404, matrixError("M_NOT_FOUND", "Unknown appservice."), "missing_registration_id")

  var reg = AppserviceRegistration()
  var found = false
  for candidate in registrations:
    if candidate.id == normalizedId:
      reg = candidate
      found = true
      break
  if not found:
    return (Http404, matrixError("M_NOT_FOUND", "Unknown appservice."), "unknown_registration")

  let token = accessToken.strip()
  if token.len == 0:
    return (Http401, matrixError("M_MISSING_TOKEN", "Missing access token."), "missing_access_token")
  if token != reg.asToken:
    return (Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."), "invalid_access_token")

  (Http200, %*{"duration_ms": 0}, "")

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
    loginTokens: initTable[string, LoginTokenRecord](),
    refreshTokens: loaded.refreshTokens,
    ssoSessions: loaded.ssoSessions,
    devices: loaded.devices,
    rooms: loaded.rooms,
    accountData: loaded.accountData,
    filters: loaded.filters,
    pushers: loaded.pushers,
    pushRules: loaded.pushRules,
    backupCounter: loaded.backupCounter,
    backupVersions: loaded.backupVersions,
    backupSessions: loaded.backupSessions,
    deviceKeys: loaded.deviceKeys,
    oneTimeKeys: loaded.oneTimeKeys,
    fallbackKeys: loaded.fallbackKeys,
    dehydratedDevices: loaded.dehydratedDevices,
    crossSigningKeys: loaded.crossSigningKeys,
    toDeviceEvents: loaded.toDeviceEvents,
    toDeviceTxnIds: loaded.toDeviceTxnIds,
    openIdTokens: loaded.openIdTokens,
    typing: initTable[string, TypingRecord](),
    typingUpdates: initTable[string, int64](),
    receipts: loaded.receipts,
    presence: loaded.presence,
    reports: loaded.reports,
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
  for _, session in result.tokens:
    if session.deviceId.len > 0 and deviceKey(session.userId, session.deviceId) notin result.devices:
      discard result.upsertDeviceLocked(session.userId, session.deviceId, "")

  for reg in result.appserviceRegs:
    result.appserviceByAsToken[reg.asToken] = reg
  info("Loaded appservice registrations: " & $result.appserviceRegs.len)

proc addTokenForUser(state: ServerState; userId, deviceId: string; displayName = ""): string =
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
  if deviceId.len > 0:
    discard state.upsertDeviceLocked(userId, deviceId, displayName)
  token

proc removeTokensForDevice(state: ServerState; userId, deviceId: string; keepToken = "") =
  var keptTokens: seq[string] = @[]
  if userId in state.userTokens:
    for token in state.userTokens[userId]:
      if token in state.tokens and state.tokens[token].deviceId == deviceId and token != keepToken:
        state.tokens.del(token)
      else:
        keptTokens.add(token)
    if keptTokens.len == 0:
      state.userTokens.del(userId)
    else:
      state.userTokens[userId] = keptTokens

  var staleRefresh: seq[string] = @[]
  for token, record in state.refreshTokens:
    if record.userId == userId and record.deviceId == deviceId:
      staleRefresh.add(token)
  for token in staleRefresh:
    state.refreshTokens.del(token)

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
  var staleRefresh: seq[string] = @[]
  for refreshToken, record in state.refreshTokens:
    if record.userId == session.userId and record.deviceId == session.deviceId:
      staleRefresh.add(refreshToken)
  for refreshToken in staleRefresh:
    state.refreshTokens.del(refreshToken)

proc removeAllTokensForUser(state: ServerState; userId: string) =
  if userId notin state.userTokens:
    discard
  else:
    for token in state.userTokens[userId]:
      if token in state.tokens:
        state.tokens.del(token)
    state.userTokens.del(userId)
  var staleRefresh: seq[string] = @[]
  for refreshToken, record in state.refreshTokens:
    if record.userId == userId:
      staleRefresh.add(refreshToken)
  for refreshToken in staleRefresh:
    state.refreshTokens.del(refreshToken)

proc createLoginTokenLocked(state: ServerState; userId: string; ttlMs: int64): LoginTokenRecord =
  let token = randomString("login_", 48)
  result = LoginTokenRecord(
    loginToken: token,
    userId: userId,
    expiresAtMs: nowMs() + max(1'i64, ttlMs),
  )
  state.loginTokens[token] = result

proc consumeLoginTokenLocked(
    state: ServerState;
    token: string
): tuple[ok: bool, userId: string, errcode: string, message: string] =
  if token.len == 0:
    return (false, "", "M_MISSING_PARAM", "Missing login token.")
  if token notin state.loginTokens:
    return (false, "", "M_FORBIDDEN", "Login token is unrecognized.")
  let record = state.loginTokens[token]
  state.loginTokens.del(token)
  if record.expiresAtMs <= nowMs():
    return (false, "", "M_FORBIDDEN", "Login token has expired.")
  if record.userId notin state.users:
    return (false, "", "M_FORBIDDEN", "Login token user does not exist.")
  (true, record.userId, "", "")

proc createRefreshTokenLocked(
    state: ServerState;
    userId, deviceId: string;
    ttlMs: int64
): RefreshTokenRecord =
  let token = randomString("refresh_", 48)
  result = RefreshTokenRecord(
    refreshToken: token,
    userId: userId,
    deviceId: deviceId,
    expiresAtMs: nowMs() + max(1'i64, ttlMs),
  )
  state.refreshTokens[token] = result

proc refreshAccessTokenLocked(
    state: ServerState;
    refreshToken, displayName: string;
    refreshTtlMs: int64
): tuple[ok: bool, accessToken: string, refreshToken: string, expiresInMs: int64, errcode: string, message: string] =
  if not refreshToken.startsWith("refresh_"):
    return (false, "", "", 0'i64, "M_FORBIDDEN", "Refresh token is malformed.")
  if refreshToken notin state.refreshTokens:
    return (false, "", "", 0'i64, "M_FORBIDDEN", "Refresh token is unrecognized.")
  let record = state.refreshTokens[refreshToken]
  if record.expiresAtMs <= nowMs():
    state.refreshTokens.del(refreshToken)
    return (false, "", "", 0'i64, "M_FORBIDDEN", "Refresh token has expired.")
  if record.userId notin state.users:
    state.refreshTokens.del(refreshToken)
    return (false, "", "", 0'i64, "M_FORBIDDEN", "Refresh token user does not exist.")
  state.removeTokensForDevice(record.userId, record.deviceId)
  let newAccess = state.addTokenForUser(record.userId, record.deviceId, displayName)
  let newRefresh = state.createRefreshTokenLocked(record.userId, record.deviceId, refreshTtlMs)
  (true, newAccess, newRefresh.refreshToken, refreshTtlMs, "", "")

proc membershipContent(status: string): JsonNode =
  %*{"membership": status}

proc appendEventLocked(
    state: ServerState;
    roomId, sender, eventType, stateKeyValue: string;
    content: JsonNode;
    redacts = ""
): MatrixEventRecord {.gcsafe.}

proc enqueueEventDeliveries(state: ServerState; ev: MatrixEventRecord) {.gcsafe.}

proc isStateEventForStorage(eventType, stateKeyValue: string): bool {.gcsafe.} =
  if stateKeyValue.len > 0:
    return true
  eventType in [
    "m.room.create",
    "m.room.power_levels",
    "m.room.name",
    "m.room.topic",
    "m.room.avatar",
    "m.room.canonical_alias",
    "m.room.join_rules",
    "m.room.encryption",
    "m.room.history_visibility",
    "m.room.guest_access",
    "m.room.tombstone"
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

proc setRoomMembershipLocked(
    state: ServerState;
    roomId, senderUserId, targetUserId, membership: string
): tuple[ok: bool, eventId: string] {.gcsafe.} =
  if roomId notin state.rooms or targetUserId.len == 0 or membership.len == 0:
    return (false, "")
  let ev = state.appendEventLocked(
    roomId,
    senderUserId,
    "m.room.member",
    targetUserId,
    membershipContent(membership)
  )
  state.enqueueEventDeliveries(ev)
  (true, ev.eventId)

proc forgetRoomLocked(state: ServerState; userId, roomId: string): tuple[ok: bool, changed: bool] {.gcsafe.} =
  if roomId notin state.rooms:
    return (false, false)

  let currentMembership = state.rooms[roomId].members.getOrDefault(userId, "")
  if currentMembership == "join" or currentMembership == "invite" or currentMembership == "knock":
    discard state.setRoomMembershipLocked(roomId, userId, userId, "leave")
    return (true, true)

  if userId in state.userJoinedRooms and roomId in state.userJoinedRooms[userId]:
    state.userJoinedRooms[userId].excl(roomId)
    return (true, true)

  (true, false)

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
      "m.change_password": {"enabled": true},
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
  if user.displayName.len > 0:
    payload["displayname"] = %user.displayName
  if user.avatarUrl.len > 0:
    payload["avatar_url"] = %user.avatarUrl
  if user.blurhash.len > 0:
    payload["blurhash"] = %user.blurhash
  if user.timezone.len > 0:
    payload["m.tz"] = %user.timezone
  for key, value in user.profileFields:
    if key notin ["displayname", "avatar_url", "blurhash", "m.tz", "us.cloke.msc4175.tz"]:
      payload[key] = value
  payload

proc profileFieldPayload(user: UserProfile; field: string): tuple[ok: bool, payload: JsonNode] =
  case field
  of "":
    result = (true, userProfilePayload(user))
  of "displayname":
    result = (true, %*{"displayname": user.displayName})
  of "avatar_url":
    result = (true, %*{"avatar_url": user.avatarUrl})
    if user.blurhash.len > 0:
      result.payload["blurhash"] = %user.blurhash
  of "blurhash":
    if user.blurhash.len == 0:
      return (false, newJObject())
    result = (true, %*{"blurhash": user.blurhash})
  of "m.tz", "us.cloke.msc4175.tz":
    if user.timezone.len == 0:
      return (false, newJObject())
    result = (true, newJObject())
    result.payload[field] = %user.timezone
  else:
    if field in user.profileFields:
      result = (true, newJObject())
      result.payload[field] = user.profileFields[field]
    else:
      result = (false, newJObject())

proc firstJsonFieldValue(node: JsonNode; keys: openArray[string]): JsonNode =
  if node.kind != JObject:
    return newJNull()
  for key in keys:
    if node.hasKey(key):
      return node[key]
  newJNull()

proc setUserProfileField(user: var UserProfile; field: string; body: JsonNode) =
  case field
  of "displayname":
    let value = firstJsonFieldValue(body, ["displayname"])
    if value.kind == JNull:
      user.displayName = ""
    elif value.kind == JString:
      user.displayName = value.getStr("")
  of "avatar_url":
    let value = firstJsonFieldValue(body, ["avatar_url"])
    if value.kind == JNull:
      user.avatarUrl = ""
    elif value.kind == JString:
      user.avatarUrl = value.getStr("")
    let blurhash = firstJsonFieldValue(body, ["blurhash"])
    if blurhash.kind == JNull:
      discard
    elif blurhash.kind == JString:
      user.blurhash = blurhash.getStr("")
  of "blurhash":
    let value = firstJsonFieldValue(body, ["blurhash"])
    if value.kind == JNull:
      user.blurhash = ""
    elif value.kind == JString:
      user.blurhash = value.getStr("")
  of "m.tz", "us.cloke.msc4175.tz":
    let value = firstJsonFieldValue(body, [field, "m.tz", "us.cloke.msc4175.tz"])
    if value.kind == JNull:
      user.timezone = ""
    elif value.kind == JString:
      user.timezone = value.getStr("")
  else:
    if body.kind == JObject and body.hasKey(field):
      user.profileFields[field] = body[field]
    else:
      user.profileFields[field] = body

proc deleteUserProfileField(user: var UserProfile; field: string) =
  case field
  of "displayname":
    user.displayName = ""
  of "avatar_url":
    user.avatarUrl = ""
    user.blurhash = ""
  of "blurhash":
    user.blurhash = ""
  of "m.tz", "us.cloke.msc4175.tz":
    user.timezone = ""
    user.profileFields.del("m.tz")
    user.profileFields.del("us.cloke.msc4175.tz")
  else:
    user.profileFields.del(field)

proc roomJoinedForUser(state: ServerState; roomId, userId: string): bool =
  if roomId notin state.rooms:
    return false
  let room = state.rooms[roomId]
  room.members.getOrDefault(userId, "") == "join"

proc usersShareJoinedRoom(state: ServerState; a, b: string): bool =
  if a == b:
    return true
  if a notin state.userJoinedRooms or b notin state.userJoinedRooms:
    return false
  for roomId in state.userJoinedRooms[a]:
    if roomId in state.userJoinedRooms[b]:
      return true
  false

proc joinedRoomsForUser(state: ServerState; userId: string): seq[string] =
  result = @[]
  if userId notin state.userJoinedRooms:
    return
  for roomId in state.userJoinedRooms[userId]:
    result.add(roomId)
  result.sort(system.cmp[string])

proc mutualRoomsPayloadLocked(state: ServerState; requesterUserId, targetUserId: string): JsonNode =
  var joined = newJArray()
  if (targetUserId in state.users or targetUserId in state.userJoinedRooms) and
      requesterUserId in state.userJoinedRooms and targetUserId in state.userJoinedRooms:
    var shared: seq[string] = @[]
    for roomId in state.userJoinedRooms[requesterUserId]:
      if roomId in state.userJoinedRooms[targetUserId]:
        shared.add(roomId)
    shared.sort(system.cmp[string])
    for roomId in shared:
      joined.add(%roomId)
  result = %*{"joined": joined}
  result["next_batch_token"] = newJNull()

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

proc roomMembersArray(room: RoomData; membership, notMembership: string): JsonNode =
  var entries = newJArray()
  var allState: seq[MatrixEventRecord] = @[]
  for _, ev in room.stateByKey:
    if ev.eventType != "m.room.member":
      continue
    let current = ev.content{"membership"}.getStr("")
    if membership.len > 0 and current != membership:
      continue
    if notMembership.len > 0 and current == notMembership:
      continue
    allState.add(ev)
  allState.sort(proc(a, b: MatrixEventRecord): int = cmp(a.streamPos, b.streamPos))
  for ev in allState:
    entries.add(ev.eventToJson())
  entries

proc roomEventIndex(room: RoomData; eventId: string): int =
  for idx, ev in room.timeline:
    if ev.eventId == eventId:
      return idx
  -1

proc appendReportLocked(
    state: ServerState;
    reporterUserId, roomId, eventId, reason: string;
    score: int
): ReportRecord =
  inc state.streamPos
  result = ReportRecord(
    reportId: "report_" & $state.streamPos,
    reporterUserId: reporterUserId,
    roomId: roomId,
    eventId: eventId,
    reason: reason,
    score: score,
    ts: nowMs(),
    streamPos: state.streamPos,
  )
  state.reports.add(result)

proc roomAliasesPayload(room: RoomData): JsonNode =
  var seen = initHashSet[string]()
  var aliases = newJArray()
  let key = stateKey("m.room.canonical_alias", "")
  if key in room.stateByKey:
    let content = room.stateByKey[key].content
    if content.isNil or content.kind != JObject:
      return %*{"aliases": aliases}
    let canonical = content.getOrDefault("alias").getStr("")
    if canonical.len > 0:
      aliases.add(%canonical)
      seen.incl(canonical)
    if content.hasKey("alt_aliases") and content["alt_aliases"].kind == JArray:
      for aliasNode in content["alt_aliases"]:
        let alias = aliasNode.getStr("")
        if alias.len > 0 and alias notin seen:
          aliases.add(%alias)
          seen.incl(alias)
  %*{"aliases": aliases}

proc roomHasAlias(room: RoomData; alias: string): bool =
  if alias.len == 0:
    return false
  let key = stateKey("m.room.canonical_alias", "")
  if key notin room.stateByKey:
    return false
  let content = room.stateByKey[key].content
  if content.isNil or content.kind != JObject:
    return false
  if content.getOrDefault("alias").getStr("") == alias:
    return true
  if content.hasKey("alt_aliases") and content["alt_aliases"].kind == JArray:
    for node in content["alt_aliases"]:
      if node.getStr("") == alias:
        return true
  false

proc findRoomByAliasLocked(state: ServerState; alias: string): string =
  for roomId, room in state.rooms:
    if room.roomHasAlias(alias):
      return roomId
  ""

proc roomJoinRule(room: RoomData): string =
  let key = stateKey("m.room.join_rules", "")
  if key notin room.stateByKey:
    return "invite"
  let content = room.stateByKey[key].content
  if content.isNil or content.kind != JObject:
    return "invite"
  content.getOrDefault("join_rule").getStr("invite")

proc roomIsPublic(room: RoomData): bool =
  room.roomJoinRule() == "public"

proc roomWorldReadable(room: RoomData): bool =
  let key = stateKey("m.room.history_visibility", "")
  if key notin room.stateByKey:
    return false
  let content = room.stateByKey[key].content
  not content.isNil and content.kind == JObject and
    content.getOrDefault("history_visibility").getStr("") == "world_readable"

proc roomGuestCanJoin(room: RoomData): bool =
  let key = stateKey("m.room.guest_access", "")
  if key notin room.stateByKey:
    return false
  let content = room.stateByKey[key].content
  not content.isNil and content.kind == JObject and
    content.getOrDefault("guest_access").getStr("") == "can_join"

proc roomVisibleToUser(state: ServerState; roomId, userId: string): bool =
  if roomId notin state.rooms:
    return false
  let room = state.rooms[roomId]
  state.roomJoinedForUser(roomId, userId) or room.roomIsPublic() or room.roomWorldReadable()

proc aliasContentWith(room: RoomData; alias: string): JsonNode =
  let key = stateKey("m.room.canonical_alias", "")
  if key in room.stateByKey and room.stateByKey[key].content.kind == JObject:
    result = room.stateByKey[key].content.copy()
  else:
    result = newJObject()

  let existingAlias = result.getOrDefault("alias").getStr("")
  if existingAlias.len == 0:
    result["alias"] = %alias
    return
  if existingAlias == alias:
    return

  var alt = newJArray()
  var seen = initHashSet[string]()
  if result.hasKey("alt_aliases") and result["alt_aliases"].kind == JArray:
    for node in result["alt_aliases"]:
      let item = node.getStr("")
      if item.len > 0 and item != existingAlias and item notin seen:
        alt.add(%item)
        seen.incl(item)
  if alias notin seen:
    alt.add(%alias)
  result["alt_aliases"] = alt

proc aliasContentWithout(room: RoomData; alias: string): JsonNode =
  let key = stateKey("m.room.canonical_alias", "")
  if key in room.stateByKey and room.stateByKey[key].content.kind == JObject:
    result = room.stateByKey[key].content.copy()
  else:
    return newJObject()

  var altValues: seq[string] = @[]
  if result.hasKey("alt_aliases") and result["alt_aliases"].kind == JArray:
    for node in result["alt_aliases"]:
      let item = node.getStr("")
      if item.len > 0 and item != alias:
        altValues.add(item)

  if result.getOrDefault("alias").getStr("") == alias:
    if altValues.len > 0:
      result["alias"] = %altValues[0]
      altValues.delete(0)
    elif result.hasKey("alias"):
      result.delete("alias")

  var alt = newJArray()
  for item in altValues:
    if item != result.getOrDefault("alias").getStr(""):
      alt.add(%item)
  if alt.len > 0:
    result["alt_aliases"] = alt
  elif result.hasKey("alt_aliases"):
    result.delete("alt_aliases")

proc roomContextPayload(room: RoomData; eventIndex: int; limit: int): JsonNode =
  var eventsBefore = newJArray()
  var eventsAfter = newJArray()
  let beforeLimit = max(0, limit div 2)
  let afterLimit = max(0, limit - beforeLimit)

  var beforeCount = 0
  var idx = eventIndex - 1
  while idx >= 0 and beforeCount < beforeLimit:
    eventsBefore.add(room.timeline[idx].eventToJson())
    inc beforeCount
    dec idx

  var afterCount = 0
  idx = eventIndex + 1
  while idx < room.timeline.len and afterCount < afterLimit:
    eventsAfter.add(room.timeline[idx].eventToJson())
    inc afterCount
    inc idx

  let basePos = room.timeline[eventIndex].streamPos
  let startPos =
    if beforeCount > 0:
      room.timeline[eventIndex - beforeCount].streamPos
    else:
      basePos
  let endPos =
    if afterCount > 0:
      room.timeline[eventIndex + afterCount].streamPos
    else:
      basePos

  %*{
    "event": room.timeline[eventIndex].eventToJson(),
    "events_before": eventsBefore,
    "events_after": eventsAfter,
    "start": encodeSinceToken(startPos),
    "end": encodeSinceToken(endPos),
    "state": roomStateArray(room),
  }

proc addJsonStringLeaves(node: JsonNode; values: var seq[string]) =
  case node.kind
  of JString:
    values.add(node.getStr(""))
  of JObject:
    for _, child in node:
      addJsonStringLeaves(child, values)
  of JArray:
    for child in node:
      addJsonStringLeaves(child, values)
  else:
    discard

proc eventSearchHaystack(ev: MatrixEventRecord): string =
  var values = @[ev.eventType, ev.sender]
  addJsonStringLeaves(ev.content, values)
  values.join(" ").toLowerAscii()

proc searchHighlights(searchTerm: string): JsonNode =
  result = newJArray()
  var seen = initHashSet[string]()
  for raw in searchTerm.split(AllChars - Letters - Digits):
    let term = raw.strip().toLowerAscii()
    if term.len == 0 or term in seen:
      continue
    seen.incl(term)
    result.add(%term)

proc roomEventContextPayload(room: RoomData; eventIndex: int; limit: int): JsonNode =
  let context = roomContextPayload(room, eventIndex, limit)
  %*{
    "profile_info": {},
    "events_before": context["events_before"],
    "events_after": context["events_after"],
    "start": context["start"],
    "end": context["end"],
  }

proc parseStreamToken(raw: string): int64 =
  if raw.len == 0:
    return 0
  result = parseSinceToken(raw)
  if result > 0 or raw == "s0":
    return
  try:
    result = parseInt(raw).int64
  except ValueError:
    result = 0

proc eventStreamPayload(
    state: ServerState;
    userId, requestedRoomId, fromToken: string;
    limit = 50
): tuple[ok: bool, payload: JsonNode] =
  let fromPos = parseStreamToken(fromToken)
  var roomIds: seq[string] = @[]
  if requestedRoomId.len > 0:
    if requestedRoomId notin state.rooms or not state.roomJoinedForUser(requestedRoomId, userId):
      return (false, newJObject())
    roomIds.add(requestedRoomId)
  else:
    roomIds = state.joinedRoomsForUser(userId)

  type EventHit = object
    streamPos: int64
    roomId: string
    eventIndex: int

  var hits: seq[EventHit] = @[]
  for roomId in roomIds:
    if roomId notin state.rooms:
      continue
    let room = state.rooms[roomId]
    for idx, ev in room.timeline:
      if ev.streamPos > fromPos:
        hits.add(EventHit(streamPos: ev.streamPos, roomId: roomId, eventIndex: idx))
  hits.sort(proc(a, b: EventHit): int =
    let posCmp = cmp(a.streamPos, b.streamPos)
    if posCmp != 0:
      posCmp
    else:
      cmp(a.roomId, b.roomId)
  )

  let capped = max(1, min(50, limit))
  var chunk = newJArray()
  var firstPos = 0'i64
  var lastPos = 0'i64
  for idx, hit in hits:
    if idx >= capped:
      break
    let ev = state.rooms[hit.roomId].timeline[hit.eventIndex]
    if firstPos == 0:
      firstPos = ev.streamPos
    lastPos = ev.streamPos
    chunk.add(ev.eventToJson())

  (true, %*{
    "chunk": chunk,
    "start": if firstPos > 0: encodeSinceToken(firstPos) else: fromToken,
    "end": if lastPos > 0: encodeSinceToken(lastPos) else: encodeSinceToken(state.streamPos),
  })

proc notificationsPayload(
    state: ServerState;
    userId, fromToken, only: string;
    limit: int
): JsonNode =
  var notifications = newJArray()
  let onlyLower = only.toLowerAscii()
  if onlyLower.len > 0 and "highlight" in onlyLower:
    return %*{"notifications": notifications}

  let fromPos = parseStreamToken(fromToken)
  type NotificationHit = object
    ev: MatrixEventRecord
  var hits: seq[NotificationHit] = @[]
  if userId in state.userJoinedRooms:
    for roomId in state.userJoinedRooms[userId]:
      if roomId notin state.rooms:
        continue
      for ev in state.rooms[roomId].timeline:
        if ev.streamPos <= fromPos:
          continue
        if ev.sender == userId:
          continue
        hits.add(NotificationHit(ev: ev))

  hits.sort(proc(a, b: NotificationHit): int =
    let posCmp = cmp(b.ev.streamPos, a.ev.streamPos)
    if posCmp != 0: posCmp else: cmp(a.ev.eventId, b.ev.eventId)
  )

  let capped = max(1, min(100, limit))
  let count = min(capped, hits.len)
  for idx in 0 ..< count:
    let ev = hits[idx].ev
    notifications.add(%*{
      "room_id": ev.roomId,
      "event": ev.eventToJson(),
      "ts": ev.originServerTs,
      "read": false,
      "actions": ["notify"]
    })

  result = %*{"notifications": notifications}
  if hits.len > count and count > 0:
    result["next_token"] = %encodeSinceToken(hits[count - 1].ev.streamPos)

proc relationTargetEventId(ev: MatrixEventRecord): string =
  result = ""
  if ev.content.isNil or ev.content.kind != JObject or not ev.content.hasKey("m.relates_to"):
    return ""
  let relates = ev.content["m.relates_to"]
  if relates.kind != JObject:
    return ""
  if relates.hasKey("event_id"):
    result = relates["event_id"].getStr("")
  if result.len == 0 and relates.hasKey("m.in_reply_to") and relates["m.in_reply_to"].kind == JObject:
    result = relates["m.in_reply_to"].getOrDefault("event_id").getStr("")

proc relationType(ev: MatrixEventRecord): string =
  result = ""
  if ev.content.isNil or ev.content.kind != JObject or not ev.content.hasKey("m.relates_to"):
    return ""
  let relates = ev.content["m.relates_to"]
  if relates.kind != JObject:
    return ""
  if relates.hasKey("rel_type"):
    result = relates["rel_type"].getStr("")
  if result.len == 0 and relates.hasKey("m.in_reply_to") and
      relates["m.in_reply_to"].kind == JObject and
      relates["m.in_reply_to"].getOrDefault("event_id").getStr("").len > 0:
    result = "m.in_reply_to"

proc relatedEventsPayload(
    state: ServerState;
    userId: string;
    parts: tuple[ok: bool, roomId: string, eventId: string, relType: string, eventType: string];
    fromToken, toToken, dir: string;
    limit: int;
    recurse: bool
): tuple[ok: bool, notFound: bool, payload: JsonNode] =
  if not parts.ok or parts.roomId notin state.rooms:
    return (false, true, newJObject())
  if not state.roomJoinedForUser(parts.roomId, userId):
    return (false, false, newJObject())

  let room = state.rooms[parts.roomId]
  let targetIdx = roomEventIndex(room, parts.eventId)
  if targetIdx < 0:
    return (true, false, %*{"chunk": [], "next_batch": "", "prev_batch": ""})

  let fromPos = parseStreamToken(fromToken)
  let toPos = parseStreamToken(toToken)
  let backwards = dir.toLowerAscii() in ["", "b"]
  let capped = max(1, min(100, limit))
  let maxDepth = if recurse: 3 else: 0

  type RelationHit = object
    depth: int
    streamPos: int64
    eventIndex: int

  var frontier = @[parts.eventId]
  var seenTargets = initHashSet[string]()
  var hits: seq[RelationHit] = @[]
  var depth = 0
  while frontier.len > 0:
    if depth > maxDepth:
      break
    var nextFrontier: seq[string] = @[]
    for targetEventId in frontier:
      if targetEventId in seenTargets:
        continue
      seenTargets.incl(targetEventId)
      for idx, ev in room.timeline:
        if ev.relationTargetEventId() != targetEventId:
          continue
        if parts.relType.len > 0 and ev.relationType() != parts.relType:
          continue
        if parts.eventType.len > 0 and ev.eventType != parts.eventType:
          continue
        hits.add(RelationHit(depth: depth, streamPos: ev.streamPos, eventIndex: idx))
        if recurse:
          nextFrontier.add(ev.eventId)
    frontier = nextFrontier
    inc depth

  hits.sort(proc(a, b: RelationHit): int =
    let posCmp = if backwards: cmp(b.streamPos, a.streamPos) else: cmp(a.streamPos, b.streamPos)
    if posCmp != 0:
      posCmp
    else:
      cmp(a.eventIndex, b.eventIndex)
  )

  var filtered: seq[RelationHit] = @[]
  for hit in hits:
    if fromPos > 0:
      if backwards and hit.streamPos >= fromPos:
        continue
      if not backwards and hit.streamPos <= fromPos:
        continue
    if toPos > 0:
      if backwards and hit.streamPos <= toPos:
        continue
      if not backwards and hit.streamPos >= toPos:
        continue
    filtered.add(hit)

  var chunk = newJArray()
  var emitted: seq[RelationHit] = @[]
  for hit in filtered:
    if emitted.len >= capped:
      break
    emitted.add(hit)
    chunk.add(room.timeline[hit.eventIndex].eventToJson())

  var payload = %*{
    "chunk": chunk,
    "prev_batch": if emitted.len > 0: encodeSinceToken(emitted[0].streamPos) else: fromToken,
    "next_batch": if emitted.len > 0: encodeSinceToken(emitted[^1].streamPos) else: "",
  }
  if recurse:
    var maxSeen = 0
    for hit in emitted:
      maxSeen = max(maxSeen, hit.depth)
    payload["recursion_depth"] = %maxSeen
  (true, false, payload)

proc threadRootEventId(ev: MatrixEventRecord): string =
  result = ""
  if ev.content.isNil or ev.content.kind != JObject or not ev.content.hasKey("m.relates_to"):
    return ""
  let relates = ev.content["m.relates_to"]
  if relates.kind != JObject:
    return ""
  if relates.getOrDefault("rel_type").getStr("") == "m.thread":
    result = relates.getOrDefault("event_id").getStr("")

proc threadEventsPayload(
    state: ServerState;
    userId, roomId, fromToken: string;
    limit: int
): tuple[ok: bool, notFound: bool, payload: JsonNode] =
  if roomId notin state.rooms:
    return (false, true, newJObject())
  if not state.roomJoinedForUser(roomId, userId):
    return (false, false, newJObject())

  let room = state.rooms[roomId]
  let fromPos = parseStreamToken(fromToken)
  let capped = max(1, min(100, limit))
  var roots = initHashSet[string]()
  for ev in room.timeline:
    let root = ev.threadRootEventId()
    if root.len > 0:
      roots.incl(root)

  var candidates: seq[MatrixEventRecord] = @[]
  for ev in room.timeline:
    if ev.eventId in roots and (fromPos == 0 or ev.streamPos < fromPos):
      candidates.add(ev)

  candidates.sort(proc(a, b: MatrixEventRecord): int = cmp(b.streamPos, a.streamPos))

  var chunk = newJArray()
  var lastPos = 0'i64
  for ev in candidates:
    if chunk.len >= capped:
      break
    chunk.add(ev.eventToJson())
    lastPos = ev.streamPos

  var payload = %*{"chunk": chunk}
  if candidates.len > capped and lastPos > 0:
    payload["next_batch"] = %encodeSinceToken(lastPos)
  else:
    payload["next_batch"] = %""
  (true, false, payload)

proc searchRoomEventsPayload(
    state: ServerState;
    userId: string;
    body: JsonNode;
    nextBatchToken: string
): JsonNode =
  let criteria = body{"search_categories"}{"room_events"}
  if criteria.kind != JObject:
    return %*{"search_categories": {"room_events": {
      "count": 0,
      "highlights": [],
      "results": [],
      "state": {}
    }}}

  let searchTerm = criteria{"search_term"}.getStr("")
  let filter = criteria{"filter"}
  let limit =
    if filter.kind == JObject:
      if filter.hasKey("limit"):
        max(1, min(100, filter["limit"].getInt(10)))
      else:
        10
    else:
      10
  var skip = 0
  if nextBatchToken.len > 0:
    try:
      skip = max(0, parseInt(nextBatchToken))
    except ValueError:
      skip = 0

  var candidateRooms: seq[string] = @[]
  if filter.kind == JObject and filter.hasKey("rooms") and filter["rooms"].kind == JArray:
    var seen = initHashSet[string]()
    for roomNode in filter["rooms"]:
      let roomId = roomNode.getStr("")
      if roomId.len > 0 and roomId notin seen:
        seen.incl(roomId)
        candidateRooms.add(roomId)
  else:
    candidateRooms = state.joinedRoomsForUser(userId)
  candidateRooms.sort(system.cmp[string])

  type SearchHit = object
    roomId: string
    eventIndex: int
    streamPos: int64

  var hits: seq[SearchHit] = @[]
  let loweredTerm = searchTerm.toLowerAscii()
  for roomId in candidateRooms:
    if roomId notin state.rooms:
      continue
    if not state.roomJoinedForUser(roomId, userId):
      continue
    let room = state.rooms[roomId]
    for idx, ev in room.timeline:
      if loweredTerm.len > 0 and loweredTerm notin ev.eventSearchHaystack():
        continue
      hits.add(SearchHit(roomId: roomId, eventIndex: idx, streamPos: ev.streamPos))

  hits.sort(proc(a, b: SearchHit): int =
    let posCmp = cmp(b.streamPos, a.streamPos)
    if posCmp != 0:
      posCmp
    else:
      cmp(a.roomId, b.roomId)
  )

  var results = newJArray()
  let endExclusive = min(hits.len, skip + limit)
  if skip < hits.len:
    for idx in skip ..< endExclusive:
      let hit = hits[idx]
      let room = state.rooms[hit.roomId]
      let ev = room.timeline[hit.eventIndex]
      results.add(%*{
        "rank": 1.0,
        "result": ev.eventToJson(),
        "context": roomEventContextPayload(room, hit.eventIndex, 2),
      })

  var statePayload = newJObject()
  if criteria.hasKey("include_state") and criteria["include_state"].getBool(false):
    var stateRooms = initHashSet[string]()
    for hit in hits:
      if hit.roomId in stateRooms:
        continue
      stateRooms.incl(hit.roomId)
      if hit.roomId in state.rooms:
        statePayload[hit.roomId] = roomStateArray(state.rooms[hit.roomId])

  var roomEvents = %*{
    "count": hits.len,
    "highlights": searchHighlights(searchTerm),
    "results": results,
    "state": statePayload,
  }
  if endExclusive < hits.len:
    roomEvents["next_batch"] = %($endExclusive)

  %*{"search_categories": {"room_events": roomEvents}}

proc joinedMemberCount(room: RoomData): int =
  result = 0
  for _, membership in room.members:
    if membership == "join":
      inc result

proc roomDisplayName(room: RoomData): string =
  result = ""
  let nameKey = stateKey("m.room.name", "")
  if nameKey in room.stateByKey and
      not room.stateByKey[nameKey].content.isNil and
      room.stateByKey[nameKey].content.kind == JObject:
    result = room.stateByKey[nameKey].content.getOrDefault("name").getStr("")
  if result.len == 0:
    let aliasKey = stateKey("m.room.canonical_alias", "")
    if aliasKey in room.stateByKey and
        not room.stateByKey[aliasKey].content.isNil and
        room.stateByKey[aliasKey].content.kind == JObject:
      result = room.stateByKey[aliasKey].content.getOrDefault("alias").getStr("")
  if result.len == 0:
    result = room.roomId

proc publicRoomsPayload(state: ServerState; body: JsonNode = nil): JsonNode =
  var searchTerm = ""
  var startIndex = 0
  var limit = high(int)
  if body != nil and body.kind == JObject:
    if body.hasKey("filter") and body["filter"].kind == JObject:
      searchTerm = body["filter"].getOrDefault("generic_search_term").getStr("").toLowerAscii()
    if body.hasKey("limit"):
      limit = max(0, body["limit"].getInt(limit))
    if body.hasKey("since"):
      try:
        startIndex = max(0, parseInt(body["since"].getStr("0")))
      except ValueError:
        startIndex = 0

  var chunk = newJArray()
  var rooms: seq[RoomData] = @[]
  for _, room in state.rooms:
    if room.roomIsPublic():
      rooms.add(room)
  rooms.sort(proc(a, b: RoomData): int = cmp(a.roomId, b.roomId))
  var filtered: seq[RoomData] = @[]
  for room in rooms:
    let aliases = room.roomAliasesPayload()
    let canonicalAlias =
      if aliases["aliases"].len > 0:
        aliases["aliases"][0].getStr("")
      else:
        ""
    if searchTerm.len > 0:
      let haystack = (room.roomId & " " & room.roomDisplayName() & " " & canonicalAlias).toLowerAscii()
      if not haystack.contains(searchTerm):
        continue
    filtered.add(room)

  let capped =
    if limit == high(int):
      filtered.len
    else:
      min(limit, max(0, filtered.len - startIndex))
  let endIndex = min(filtered.len, startIndex + capped)
  if startIndex < endIndex:
    for idx in startIndex ..< endIndex:
      let room = filtered[idx]
      let aliases = room.roomAliasesPayload()
      let canonicalAlias =
        if aliases["aliases"].len > 0:
          aliases["aliases"][0].getStr("")
        else:
          ""
      var entry = %*{
        "room_id": room.roomId,
        "name": room.roomDisplayName(),
        "num_joined_members": room.joinedMemberCount(),
        "world_readable": false,
        "guest_can_join": false,
      }
      if canonicalAlias.len > 0:
        entry["canonical_alias"] = %canonicalAlias
      chunk.add(entry)
  result = %*{
    "chunk": chunk,
    "total_room_count_estimate": filtered.len,
  }
  if startIndex + capped < filtered.len:
    result["next_batch"] = %($(startIndex + capped))

proc userDirectorySearchPayload(state: ServerState; body: JsonNode): JsonNode =
  let searchTerm = body{"search_term"}.getStr("").toLowerAscii()
  let limit = max(1, min(100, body{"limit"}.getInt(10)))
  var users: seq[UserProfile] = @[]
  for _, user in state.users:
    users.add(user)
  users.sort(proc(a, b: UserProfile): int = cmp(a.userId, b.userId))
  var matchedUsers: seq[UserProfile] = @[]
  for user in users:
    let haystack = (user.userId & " " & user.username & " " & user.displayName).toLowerAscii()
    if searchTerm.len > 0 and searchTerm notin haystack:
      continue
    matchedUsers.add(user)

  var matches = newJArray()
  for user in matchedUsers:
    if matches.len >= limit:
      break
    var item = %*{"user_id": user.userId}
    if user.displayName.len > 0:
      item["display_name"] = %user.displayName
    if user.avatarUrl.len > 0:
      item["avatar_url"] = %user.avatarUrl
    matches.add(item)
  %*{"limited": matchedUsers.len > limit, "results": matches}

proc openIdTokenPayload(serverName: string): JsonNode =
  %*{
    "access_token": randomString("oidc_", 32),
    "token_type": "Bearer",
    "matrix_server_name": serverName,
    "expires_in": 3600
  }

proc createOpenIdTokenPayload(
    state: ServerState;
    userId, serverName: string;
    ttlSeconds = 3600
): JsonNode =
  let token = randomString("oidc_", 32)
  inc state.streamPos
  state.openIdTokens[token] = OpenIdTokenRecord(
    accessToken: token,
    userId: userId,
    expiresAtMs: nowMs() + max(1, ttlSeconds).int64 * 1000'i64,
    streamPos: state.streamPos,
  )
  %*{
    "access_token": token,
    "token_type": "Bearer",
    "matrix_server_name": serverName,
    "expires_in": ttlSeconds
  }

proc thirdPartyProtocolsPayload(): JsonNode =
  newJObject()

proc accountThreepidsPayload(): JsonNode =
  %*{"threepids": []}

proc wellKnownClientPayload(cfg: FlatConfig): tuple[ok: bool, payload: JsonNode] =
  let baseUrl = getConfigString(
    cfg,
    ["well_known.client", "global.well_known.client", "well_known_client"],
    "",
  ).strip()
  if baseUrl.len == 0:
    return (false, newJObject())
  (true, %*{
    "m.homeserver": {
      "base_url": baseUrl
    }
  })

proc wellKnownSupportPayload(cfg: FlatConfig): tuple[ok: bool, payload: JsonNode] =
  let supportPage = getConfigString(
    cfg,
    ["well_known.support_page", "global.well_known.support_page", "support_page", "global.support_page"],
    "",
  ).strip()
  let role = getConfigString(
    cfg,
    ["well_known.support_role", "global.well_known.support_role", "support_role", "global.support_role"],
    "",
  ).strip()
  let email = getConfigString(
    cfg,
    ["well_known.support_email", "global.well_known.support_email", "support_email", "global.support_email"],
    "",
  ).strip()
  let mxid = getConfigString(
    cfg,
    ["well_known.support_mxid", "global.well_known.support_mxid", "support_mxid", "global.support_mxid"],
    "",
  ).strip()

  if supportPage.len == 0 and role.len == 0:
    return (false, newJObject())
  if role.len > 0 and email.len == 0 and mxid.len == 0:
    return (false, newJObject())

  var contacts = newJArray()
  if role.len > 0:
    var contact = %*{"role": role}
    if email.len > 0:
      contact["email_address"] = %email
    if mxid.len > 0:
      contact["matrix_id"] = %mxid
    contacts.add(contact)

  if contacts.len == 0 and supportPage.len == 0:
    return (false, newJObject())

  var payload = %*{"contacts": contacts}
  if supportPage.len > 0:
    payload["support_page"] = %supportPage
  (true, payload)

proc wellKnownServerPayload(cfg: FlatConfig): tuple[ok: bool, payload: JsonNode] =
  let server = getConfigString(
    cfg,
    ["well_known.server", "global.well_known.server", "well_known_server"],
    "",
  ).strip()
  if server.len == 0:
    return (false, newJObject())
  (true, %*{"m.server": server})

proc sha1DigestBytes(data: string): string =
  let digest = Sha1Digest(secureHash(data))
  result = newString(digest.len)
  for idx, value in digest:
    result[idx] = char(value)

proc hmacSha1Base64(key, message: string): string =
  var keyBlock =
    if key.len > 64:
      sha1DigestBytes(key)
    else:
      key
  keyBlock.setLen(64)

  var inner = newString(64)
  var outer = newString(64)
  for idx in 0 ..< 64:
    let value = ord(keyBlock[idx])
    inner[idx] = char(value xor 0x36)
    outer[idx] = char(value xor 0x5c)
  encode(outer & sha1DigestBytes(inner & message))

proc serverKeysPayload(serverName: string): JsonNode =
  let keyId = "ed25519:nim"
  let key = encode(sha1DigestBytes("tuwunel-nim:" & serverName)).strip(trailing = true, chars = {'='})
  %*{
    "server_name": serverName,
    "valid_until_ts": nowMs() + 604800000'i64,
    "verify_keys": {
      keyId: {
        "key": key
      }
    },
    "old_verify_keys": {},
    "signatures": {
      serverName: {
        keyId: "native-nim-placeholder-signature"
      }
    }
  }

proc turnServerPayload(
    cfg: FlatConfig;
    serverName, userId: string
): tuple[ok: bool, payload: JsonNode] =
  let uris = getConfigStringArray(cfg, ["turn_uris", "global.turn_uris"])
  if uris.len == 0:
    return (false, newJObject())

  let ttl = max(0, getConfigInt(cfg, ["turn_ttl", "global.turn_ttl"], 86400))
  var username = getConfigString(cfg, ["turn_username", "global.turn_username"], "")
  var password = getConfigString(cfg, ["turn_password", "global.turn_password"], "")
  var secret = getConfigString(cfg, ["turn_secret", "global.turn_secret"], "")
  if secret.len == 0:
    let secretFile = getConfigString(cfg, ["turn_secret_file", "global.turn_secret_file"], "")
    if secretFile.len > 0 and fileExists(secretFile):
      try:
        secret = readFile(secretFile).strip()
      except CatchableError:
        secret = ""

  if secret.len > 0:
    let expiry = (nowMs() div 1000) + ttl.int64
    let turnUser =
      if userId.len > 0:
        userId
      else:
        "@" & randomString("turn_", 10).toLowerAscii() & ":" & serverName
    username = $expiry & ":" & turnUser
    password = hmacSha1Base64(secret, username)

  (true, %*{
    "uris": uris,
    "username": username,
    "password": password,
    "ttl": ttl
  })

proc emptyPushRulesPayload(): JsonNode =
  %*{
    "global": {
      "override": [],
      "content": [],
      "room": [],
      "sender": [],
      "underride": []
    }
  }

proc pushRuleKinds(): seq[string] =
  @["override", "content", "room", "sender", "underride"]

proc isPushRuleKind(kind: string): bool =
  kind in pushRuleKinds()

proc listPushersPayload(state: ServerState; userId: string): JsonNode =
  var keys: seq[string] = @[]
  for key, _ in state.pushers:
    let parts = key.split("\x1f")
    if parts.len == 3 and parts[0] == userId:
      keys.add(key)
  keys.sort(system.cmp[string])
  var arr = newJArray()
  for key in keys:
    arr.add(state.pushers[key])
  %*{"pushers": arr}

proc setPusherLocked(state: ServerState; userId: string; body: JsonNode): tuple[ok: bool, errcode: string, message: string] =
  if body.kind != JObject:
    return (false, "M_BAD_JSON", "Pusher body must be an object.")
  let appId = body{"app_id"}.getStr("")
  let pushKeyValue = body{"pushkey"}.getStr("")
  if appId.len == 0 or pushKeyValue.len == 0:
    return (false, "M_MISSING_PARAM", "app_id and pushkey are required.")
  let key = pusherKey(userId, appId, pushKeyValue)
  if body.hasKey("kind") and body["kind"].kind == JNull:
    state.pushers.del(key)
    return (true, "", "")
  var pusher = body
  pusher["app_id"] = %appId
  pusher["pushkey"] = %pushKeyValue
  if not pusher.hasKey("kind") or pusher["kind"].kind == JNull:
    pusher["kind"] = %"http"
  if not pusher.hasKey("app_display_name"):
    pusher["app_display_name"] = %""
  if not pusher.hasKey("device_display_name"):
    pusher["device_display_name"] = %""
  if not pusher.hasKey("lang"):
    pusher["lang"] = %"en"
  if not pusher.hasKey("data") or pusher["data"].kind != JObject:
    pusher["data"] = newJObject()
  state.pushers[key] = pusher
  (true, "", "")

proc normalizePushRule(rule: JsonNode; ruleId, kind: string; existing = newJObject()): JsonNode =
  result = newJObject()
  if existing.kind == JObject:
    for key, value in existing:
      result[key] = value
  if rule.kind == JObject:
    for key, value in rule:
      result[key] = value
  result["rule_id"] = %ruleId
  if not result.hasKey("default"):
    result["default"] = %false
  if not result.hasKey("enabled"):
    result["enabled"] = %true
  if not result.hasKey("actions") or result["actions"].kind != JArray:
    result["actions"] = newJArray()
  if kind == "content" and not result.hasKey("pattern"):
    result["pattern"] = %""
  if kind in ["override", "underride"] and
      (not result.hasKey("conditions") or result["conditions"].kind != JArray):
    result["conditions"] = newJArray()

proc pushRuleScopePayload(state: ServerState; userId, scope: string): JsonNode =
  result = newJObject()
  for kind in pushRuleKinds():
    result[kind] = newJArray()
  var keys: seq[string] = @[]
  for key, _ in state.pushRules:
    let parts = key.split("\x1f")
    if parts.len == 4 and parts[0] == userId and parts[1] == scope and parts[2].isPushRuleKind():
      keys.add(key)
  keys.sort(system.cmp[string])
  for key in keys:
    let parts = key.split("\x1f")
    result[parts[2]].add(state.pushRules[key])

proc pushRulesPayload(state: ServerState; userId: string): JsonNode =
  result = emptyPushRulesPayload()
  result["global"] = state.pushRuleScopePayload(userId, "global")

proc getPushRuleLocked(state: ServerState; userId, scope, kind, ruleId: string): Option[JsonNode] =
  let key = pushRuleKey(userId, scope, kind, ruleId)
  if key in state.pushRules:
    return some(state.pushRules[key])
  none(JsonNode)

proc putPushRuleLocked(state: ServerState; userId, scope, kind, ruleId: string; body: JsonNode): tuple[ok: bool, errcode: string, message: string] =
  if scope.len == 0 or kind.len == 0 or ruleId.len == 0 or not kind.isPushRuleKind():
    return (false, "M_INVALID_PARAM", "Invalid push rule path.")
  if body.kind != JObject:
    return (false, "M_BAD_JSON", "Push rule body must be an object.")
  let key = pushRuleKey(userId, scope, kind, ruleId)
  let existing = if key in state.pushRules: state.pushRules[key] else: newJObject()
  state.pushRules[key] = normalizePushRule(body, ruleId, kind, existing)
  (true, "", "")

proc updatePushRuleAttrLocked(
    state: ServerState;
    userId, scope, kind, ruleId, attr: string;
    body: JsonNode
): tuple[ok: bool, errcode: string, message: string] =
  if scope.len == 0 or kind.len == 0 or ruleId.len == 0 or not kind.isPushRuleKind():
    return (false, "M_INVALID_PARAM", "Invalid push rule path.")
  let key = pushRuleKey(userId, scope, kind, ruleId)
  var rule =
    if key in state.pushRules:
      state.pushRules[key]
    else:
      normalizePushRule(newJObject(), ruleId, kind)
  case attr
  of "enabled":
    if body.kind != JObject or not body.hasKey("enabled") or body["enabled"].kind != JBool:
      return (false, "M_BAD_JSON", "enabled must be a boolean.")
    rule["enabled"] = %body["enabled"].getBool(false)
  of "actions":
    if body.kind != JObject or not body.hasKey("actions") or body["actions"].kind != JArray:
      return (false, "M_BAD_JSON", "actions must be an array.")
    rule["actions"] = body["actions"]
  else:
      return (false, "M_INVALID_PARAM", "Unsupported push rule attribute.")
  state.pushRules[key] = normalizePushRule(rule, ruleId, kind)
  (true, "", "")

proc backupKeyCountLocked(state: ServerState; userId, version: string): int =
  result = 0
  for _, record in state.backupSessions:
    if record.userId == userId and record.version == version:
      inc result

proc backupVersionPayloadLocked(state: ServerState; record: BackupVersionRecord): JsonNode =
  %*{
    "version": record.version,
    "algorithm": record.algorithm,
    "auth_data": record.authData,
    "count": state.backupKeyCountLocked(record.userId, record.version),
    "etag": record.etag,
  }

proc latestBackupVersionLocked(state: ServerState; userId: string): string =
  result = ""
  var latestNumeric = low(int64)
  for _, record in state.backupVersions:
    if record.userId != userId:
      continue
    try:
      let numeric = parseInt(record.version).int64
      if numeric > latestNumeric:
        latestNumeric = numeric
        result = record.version
    except ValueError:
      if result.len == 0 or cmp(record.version, result) > 0:
        result = record.version

proc backupVersionExistsLocked(state: ServerState; userId, version: string): bool =
  backupVersionKey(userId, version) in state.backupVersions

proc touchBackupVersionLocked(state: ServerState; userId, version: string) =
  let key = backupVersionKey(userId, version)
  if key notin state.backupVersions:
    return
  inc state.streamPos
  var record = state.backupVersions[key]
  record.streamPos = state.streamPos
  record.etag = $state.streamPos
  state.backupVersions[key] = record

proc createBackupVersionLocked(
    state: ServerState;
    userId: string;
    body: JsonNode
): BackupVersionRecord =
  inc state.backupCounter
  inc state.streamPos
  result = BackupVersionRecord(
    userId: userId,
    version: $state.backupCounter,
    algorithm: body{"algorithm"}.getStr("m.megolm_backup.v1.curve25519-aes-sha2"),
    authData: if body.hasKey("auth_data"): body["auth_data"] else: newJObject(),
    etag: $state.streamPos,
    streamPos: state.streamPos,
  )
  state.backupVersions[backupVersionKey(userId, result.version)] = result

proc updateBackupVersionLocked(
    state: ServerState;
    userId, version: string;
    body: JsonNode
): bool =
  let key = backupVersionKey(userId, version)
  if key notin state.backupVersions:
    return false
  inc state.streamPos
  var record = state.backupVersions[key]
  record.algorithm = body{"algorithm"}.getStr(record.algorithm)
  if body.hasKey("auth_data"):
    record.authData = body["auth_data"]
  record.etag = $state.streamPos
  record.streamPos = state.streamPos
  state.backupVersions[key] = record
  true

proc deleteBackupVersionLocked(state: ServerState; userId, version: string) =
  state.backupVersions.del(backupVersionKey(userId, version))
  var sessionKeys: seq[string] = @[]
  for key, record in state.backupSessions:
    if record.userId == userId and record.version == version:
      sessionKeys.add(key)
  for key in sessionKeys:
    state.backupSessions.del(key)
  inc state.streamPos

proc backupRoomsPayloadLocked(
    state: ServerState;
    userId, version: string;
    roomFilter = ""
): JsonNode =
  var rooms = newJObject()
  var records: seq[BackupSessionRecord] = @[]
  for _, record in state.backupSessions:
    if record.userId == userId and record.version == version:
      if roomFilter.len == 0 or record.roomId == roomFilter:
        records.add(record)
  records.sort(proc(a, b: BackupSessionRecord): int =
    let roomCmp = cmp(a.roomId, b.roomId)
    if roomCmp != 0: roomCmp else: cmp(a.sessionId, b.sessionId)
  )
  for record in records:
    if not rooms.hasKey(record.roomId):
      rooms[record.roomId] = %*{"sessions": newJObject()}
    rooms[record.roomId]["sessions"][record.sessionId] = record.sessionData
  %*{"rooms": rooms}

proc backupRoomSessionsPayloadLocked(state: ServerState; userId, version, roomId: string): JsonNode =
  var sessions = newJObject()
  var records: seq[BackupSessionRecord] = @[]
  for _, record in state.backupSessions:
    if record.userId == userId and record.version == version and record.roomId == roomId:
      records.add(record)
  records.sort(proc(a, b: BackupSessionRecord): int = cmp(a.sessionId, b.sessionId))
  for record in records:
    sessions[record.sessionId] = record.sessionData
  %*{"sessions": sessions}

proc getBackupSessionLocked(
    state: ServerState;
    userId, version, roomId, sessionId: string
): tuple[ok: bool, payload: JsonNode] =
  let key = backupSessionKey(userId, version, roomId, sessionId)
  if key notin state.backupSessions:
    return (false, newJObject())
  (true, state.backupSessions[key].sessionData)

proc betterBackupSessionCandidate(oldData, newData: JsonNode): tuple[ok: bool, replace: bool, message: string] =
  if not newData.hasKey("is_verified"):
    return (false, false, "`is_verified` field should exist")
  if not newData.hasKey("first_message_index"):
    return (false, false, "`first_message_index` field should exist")
  if not newData.hasKey("forwarded_count"):
    return (false, false, "`forwarded_count` field should exist")

  let oldVerified = oldData{"is_verified"}.getBool(false)
  let newVerified = newData{"is_verified"}.getBool(false)
  if oldVerified != newVerified:
    return (true, newVerified, "")

  let oldFirst = oldData{"first_message_index"}.getInt(high(int))
  let newFirst = newData{"first_message_index"}.getInt(high(int))
  if oldFirst != newFirst:
    return (true, newFirst < oldFirst, "")

  let oldForwarded = oldData{"forwarded_count"}.getInt(high(int))
  let newForwarded = newData{"forwarded_count"}.getInt(high(int))
  (true, newForwarded < oldForwarded, "")

proc putBackupSessionLocked(
    state: ServerState;
    userId, version, roomId, sessionId: string;
    sessionData: JsonNode;
    preferBest: bool
): tuple[ok: bool, message: string] =
  if not state.backupVersionExistsLocked(userId, version):
    return (false, "Tried to update nonexistent backup.")

  let key = backupSessionKey(userId, version, roomId, sessionId)
  if preferBest and key in state.backupSessions:
    let decision = betterBackupSessionCandidate(state.backupSessions[key].sessionData, sessionData)
    if not decision.ok:
      return (false, decision.message)
    if not decision.replace:
      return (true, "")

  inc state.streamPos
  state.backupSessions[key] = BackupSessionRecord(
    userId: userId,
    version: version,
    roomId: roomId,
    sessionId: sessionId,
    sessionData: sessionData,
    streamPos: state.streamPos,
  )
  state.touchBackupVersionLocked(userId, version)
  (true, "")

proc deleteBackupSessionsLocked(state: ServerState; userId, version, roomId, sessionId: string) =
  var keys: seq[string] = @[]
  for key, record in state.backupSessions:
    if record.userId == userId and record.version == version:
      if roomId.len == 0 or record.roomId == roomId:
        if sessionId.len == 0 or record.sessionId == sessionId:
          keys.add(key)
  for key in keys:
    state.backupSessions.del(key)
  if keys.len > 0:
    state.touchBackupVersionLocked(userId, version)

proc backupMutationPayloadLocked(state: ServerState; userId, version: string): JsonNode =
  let key = backupVersionKey(userId, version)
  if key notin state.backupVersions:
    return %*{"count": 0, "etag": "0"}
  %*{
    "count": state.backupKeyCountLocked(userId, version),
    "etag": state.backupVersions[key].etag,
  }

proc splitE2eeKeyId(raw: string): tuple[ok: bool, algorithm: string, keyId: string] =
  let sep = raw.find(':')
  if sep <= 0 or sep >= raw.high:
    return (false, "", "")
  (true, raw[0 ..< sep], raw[sep + 1 .. ^1])

proc oneTimeKeyCountsLocked(state: ServerState; userId, deviceId: string): JsonNode =
  result = newJObject()
  for _, record in state.oneTimeKeys:
    if record.userId == userId and record.deviceId == deviceId:
      result[record.algorithm] = %(result.getOrDefault(record.algorithm).getInt(0) + 1)

proc unusedFallbackKeyTypesLocked(state: ServerState; userId, deviceId: string): JsonNode =
  var algorithms: seq[string] = @[]
  for _, record in state.fallbackKeys:
    if record.userId == userId and record.deviceId == deviceId and not record.used:
      algorithms.add(record.algorithm)
  algorithms.sort(system.cmp[string])
  result = newJArray()
  var seen = initHashSet[string]()
  for algorithm in algorithms:
    if algorithm in seen:
      continue
    seen.incl(algorithm)
    result.add(%algorithm)

proc storeDeviceKeysLocked(
    state: ServerState;
    userId, deviceId: string;
    keyData: JsonNode
) =
  inc state.streamPos
  var payload = keyData.copy()
  if payload.kind != JObject:
    payload = newJObject()
  payload["user_id"] = %userId
  payload["device_id"] = %deviceId
  state.deviceKeys[deviceKey(userId, deviceId)] = DeviceKeyRecord(
    userId: userId,
    deviceId: deviceId,
    keyData: payload,
    streamPos: state.streamPos,
  )

proc storeOneTimeKeyLocked(
    state: ServerState;
    userId, deviceId, algorithm, keyId: string;
    keyData: JsonNode
) =
  inc state.streamPos
  state.oneTimeKeys[oneTimeKeyStoreKey(userId, deviceId, algorithm, keyId)] = OneTimeKeyRecord(
    userId: userId,
    deviceId: deviceId,
    algorithm: algorithm,
    keyId: keyId,
    keyData: keyData,
    streamPos: state.streamPos,
  )

proc storeFallbackKeyLocked(
    state: ServerState;
    userId, deviceId, algorithm, keyId: string;
    keyData: JsonNode
) =
  var oldKeys: seq[string] = @[]
  for key, record in state.fallbackKeys:
    if record.userId == userId and record.deviceId == deviceId and record.algorithm == algorithm:
      oldKeys.add(key)
  for key in oldKeys:
    state.fallbackKeys.del(key)
  inc state.streamPos
  state.fallbackKeys[oneTimeKeyStoreKey(userId, deviceId, algorithm, keyId)] = FallbackKeyRecord(
    userId: userId,
    deviceId: deviceId,
    algorithm: algorithm,
    keyId: keyId,
    keyData: keyData,
    used: false,
    streamPos: state.streamPos,
  )

proc crossSigningResponseField(keyType: string): string =
  case keyType
  of "master":
    "master_keys"
  of "self_signing":
    "self_signing_keys"
  of "user_signing":
    "user_signing_keys"
  else:
    ""

proc storeCrossSigningKeyLocked(
    state: ServerState;
    userId, keyType: string;
    keyData: JsonNode
) =
  inc state.streamPos
  var payload = keyData.copy()
  if payload.kind != JObject:
    payload = newJObject()
  payload["user_id"] = %userId
  state.crossSigningKeys[crossSigningKey(userId, keyType)] = CrossSigningKeyRecord(
    userId: userId,
    keyType: keyType,
    keyData: payload,
    streamPos: state.streamPos,
  )

proc uploadSigningKeysLocked(
    state: ServerState;
    userId: string;
    body: JsonNode
): tuple[ok: bool, errcode: string, message: string] =
  const fields = [
    ("master_key", "master"),
    ("self_signing_key", "self_signing"),
    ("user_signing_key", "user_signing")
  ]
  for item in fields:
    let field = item[0]
    if not body.hasKey(field):
      continue
    if body[field].kind != JObject:
      return (false, "M_BAD_JSON", field & " must be an object.")
    state.storeCrossSigningKeyLocked(userId, item[1], body[field])
  (true, "", "")

proc mergeSignatureObjects(target: JsonNode; incoming: JsonNode): bool =
  result = false
  let signatures = incoming{"signatures"}
  if target.kind != JObject or signatures.kind != JObject:
    return false
  if not target.hasKey("signatures") or target["signatures"].kind != JObject:
    target["signatures"] = newJObject()
  for signerUserId, signerNode in signatures:
    if signerNode.kind != JObject:
      continue
    if not target["signatures"].hasKey(signerUserId) or target["signatures"][signerUserId].kind != JObject:
      target["signatures"][signerUserId] = newJObject()
    for keyId, signatureNode in signerNode:
      target["signatures"][signerUserId][keyId] = signatureNode
      result = true

proc crossSigningRecordMatchesTarget(record: CrossSigningKeyRecord; targetId: string): bool =
  if targetId == record.keyType:
    return true
  let keysNode = record.keyData{"keys"}
  keysNode.kind == JObject and targetId in keysNode

proc uploadKeySignaturesLocked(state: ServerState; body: JsonNode): JsonNode =
  if body.kind != JObject:
    return %*{"failures": {}}
  for userId, userNode in body:
    if userNode.kind != JObject:
      continue
    for targetId, signedNode in userNode:
      if signedNode.kind != JObject:
        continue
      let deviceStoreKey = deviceKey(userId, targetId)
      if deviceStoreKey in state.deviceKeys:
        var record = state.deviceKeys[deviceStoreKey]
        if mergeSignatureObjects(record.keyData, signedNode):
          inc state.streamPos
          record.streamPos = state.streamPos
          state.deviceKeys[deviceStoreKey] = record
        continue

      var matchedKey = ""
      for key, record in state.crossSigningKeys:
        if record.userId == userId and record.crossSigningRecordMatchesTarget(targetId):
          matchedKey = key
          break
      if matchedKey.len > 0:
        var record = state.crossSigningKeys[matchedKey]
        if mergeSignatureObjects(record.keyData, signedNode):
          inc state.streamPos
          record.streamPos = state.streamPos
          state.crossSigningKeys[matchedKey] = record
  %*{"failures": {}}

proc toDeviceTargetDeviceIds(state: ServerState; userId, rawDeviceId: string): seq[string] =
  result = @[]
  if rawDeviceId == "*":
    for _, device in state.devices:
      if device.userId == userId:
        result.add(device.deviceId)
    result.sort(system.cmp[string])
  elif rawDeviceId.len > 0:
    result.add(rawDeviceId)

proc storeToDeviceEventLocked(
    state: ServerState;
    targetUserId, targetDeviceId, sender, eventType, txnId: string;
    content: JsonNode
) =
  inc state.streamPos
  state.toDeviceEvents[toDeviceEventKey(targetUserId, targetDeviceId, state.streamPos)] =
    ToDeviceEventRecord(
      targetUserId: targetUserId,
      targetDeviceId: targetDeviceId,
      sender: sender,
      eventType: eventType,
      txnId: txnId,
      content: content.copy(),
      streamPos: state.streamPos,
    )

proc queueToDeviceMessagesLocked(
    state: ServerState;
    sender, senderDeviceId, eventType, txnId: string;
    body: JsonNode
): tuple[ok: bool, errcode: string, message: string, queuedCount: int] =
  result = (false, "", "", 0)
  if eventType.len == 0:
    return (false, "M_INVALID_PARAM", "Event type is required.", 0)
  if txnId.len == 0:
    return (false, "M_INVALID_PARAM", "Transaction id is required.", 0)
  if body.kind != JObject:
    return (false, "M_BAD_JSON", "Invalid JSON body.", 0)
  let messages = body{"messages"}
  if messages.kind != JObject:
    return (false, "M_BAD_JSON", "messages must be an object.", 0)

  let transactionKey = toDeviceTxnKey(sender, senderDeviceId, txnId)
  if transactionKey in state.toDeviceTxnIds:
    return (true, "", "", 0)

  for targetUserId, deviceMap in messages:
    if targetUserId.len == 0 or deviceMap.kind != JObject:
      return (false, "M_BAD_JSON", "messages must map user ids to device maps.", 0)
    for rawDeviceId, content in deviceMap:
      if rawDeviceId.len == 0:
        return (false, "M_BAD_JSON", "Device id is required.", 0)
      for targetDeviceId in state.toDeviceTargetDeviceIds(targetUserId, rawDeviceId):
        state.storeToDeviceEventLocked(
          targetUserId,
          targetDeviceId,
          sender,
          eventType,
          txnId,
          content,
        )
        inc result.queuedCount

  state.toDeviceTxnIds.incl(transactionKey)
  result.ok = true

proc toDeviceEventJson(record: ToDeviceEventRecord): JsonNode =
  %*{
    "type": record.eventType,
    "sender": record.sender,
    "content": record.content,
  }

proc toDeviceEventsForSync(
    state: ServerState;
    userId, deviceId: string;
    sincePos, toPos: int64
): JsonNode =
  result = newJArray()
  if userId.len == 0 or deviceId.len == 0:
    return
  var records: seq[ToDeviceEventRecord] = @[]
  for _, record in state.toDeviceEvents:
    if record.targetUserId == userId and record.targetDeviceId == deviceId and
        record.streamPos > sincePos and record.streamPos <= toPos:
      records.add(record)
  records.sort(proc(a, b: ToDeviceEventRecord): int = cmp(a.streamPos, b.streamPos))
  for record in records:
    result.add(record.toDeviceEventJson())

proc removeToDeviceEventsLocked(
    state: ServerState;
    userId, deviceId: string;
    untilPos: int64
): bool =
  if userId.len == 0 or deviceId.len == 0 or untilPos <= 0:
    return false
  var keys: seq[string] = @[]
  for key, record in state.toDeviceEvents:
    if record.targetUserId == userId and record.targetDeviceId == deviceId and
        record.streamPos <= untilPos:
      keys.add(key)
  for key in keys:
    state.toDeviceEvents.del(key)
  keys.len > 0

proc uploadE2eeKeysLocked(
    state: ServerState;
    userId, deviceId: string;
    body: JsonNode
): tuple[ok: bool, errcode: string, message: string, payload: JsonNode] =
  if deviceId.len == 0:
    return (false, "M_INVALID_PARAM", "Device id is required for key upload.", newJObject())

  if body.hasKey("device_keys"):
    if body["device_keys"].kind != JObject:
      return (false, "M_BAD_JSON", "device_keys must be an object.", newJObject())
    state.storeDeviceKeysLocked(userId, deviceId, body["device_keys"])

  if body.hasKey("one_time_keys"):
    if body["one_time_keys"].kind != JObject:
      return (false, "M_BAD_JSON", "one_time_keys must be an object.", newJObject())
    for rawKeyId, keyData in body["one_time_keys"]:
      let parsed = splitE2eeKeyId(rawKeyId)
      if not parsed.ok:
        return (false, "M_INVALID_PARAM", "Invalid one-time key id.", newJObject())
      state.storeOneTimeKeyLocked(userId, deviceId, parsed.algorithm, parsed.keyId, keyData)

  if body.hasKey("fallback_keys"):
    if body["fallback_keys"].kind != JObject:
      return (false, "M_BAD_JSON", "fallback_keys must be an object.", newJObject())
    for rawKeyId, keyData in body["fallback_keys"]:
      let parsed = splitE2eeKeyId(rawKeyId)
      if not parsed.ok:
        return (false, "M_INVALID_PARAM", "Invalid fallback key id.", newJObject())
      state.storeFallbackKeyLocked(userId, deviceId, parsed.algorithm, parsed.keyId, keyData)

  (true, "", "", %*{
    "one_time_key_counts": state.oneTimeKeyCountsLocked(userId, deviceId),
    "device_unused_fallback_key_types": state.unusedFallbackKeyTypesLocked(userId, deviceId),
  })

proc deviceKeyPayload(userId: string; device: DeviceRecord): JsonNode =
  %*{
    "user_id": userId,
    "device_id": device.deviceId,
    "algorithms": [],
    "keys": {},
    "signatures": {}
  }

proc keysQueryPayload(state: ServerState; body: JsonNode): JsonNode =
  var deviceKeys = newJObject()
  var crossSigningPayloads = {
    "master": newJObject(),
    "self_signing": newJObject(),
    "user_signing": newJObject()
  }.toTable
  let requested = body{"device_keys"}
  if requested.kind == JObject:
    for userId, devicesNode in requested:
      var userDevices = newJObject()
      if devicesNode.kind == JArray and devicesNode.len > 0:
        for deviceNode in devicesNode:
          let deviceId = deviceNode.getStr("")
          let key = deviceKey(userId, deviceId)
          if key in state.deviceKeys:
            userDevices[deviceId] = state.deviceKeys[key].keyData
          elif key in state.devices:
            userDevices[deviceId] = deviceKeyPayload(userId, state.devices[key])
      else:
        for _, device in state.devices:
          if device.userId == userId:
            let key = deviceKey(userId, device.deviceId)
            if key in state.deviceKeys:
              userDevices[device.deviceId] = state.deviceKeys[key].keyData
            else:
              userDevices[device.deviceId] = deviceKeyPayload(userId, device)
      if userDevices.len > 0:
        deviceKeys[userId] = userDevices
      for keyType, payload in crossSigningPayloads.mpairs:
        let key = crossSigningKey(userId, keyType)
        if key in state.crossSigningKeys:
          payload[userId] = state.crossSigningKeys[key].keyData
  result = %*{
    "device_keys": deviceKeys,
    "failures": {}
  }
  for keyType, payload in crossSigningPayloads:
    let field = crossSigningResponseField(keyType)
    if field.len > 0:
      result[field] = payload

proc claimE2eeKeysLocked(state: ServerState; body: JsonNode): JsonNode =
  var oneTimeKeys = newJObject()
  let requested = body{"one_time_keys"}
  if requested.kind == JObject:
    for userId, devicesNode in requested:
      if devicesNode.kind != JObject:
        continue
      var userPayload = newJObject()
      for deviceId, algorithmNode in devicesNode:
        let requestedAlgorithm = algorithmNode.getStr("")
        if requestedAlgorithm.len == 0:
          continue

        var candidates: seq[OneTimeKeyRecord] = @[]
        for _, record in state.oneTimeKeys:
          if record.userId == userId and record.deviceId == deviceId and record.algorithm == requestedAlgorithm:
            candidates.add(record)
        candidates.sort(proc(a, b: OneTimeKeyRecord): int =
          let posCmp = cmp(a.streamPos, b.streamPos)
          if posCmp != 0: posCmp else: cmp(a.keyId, b.keyId)
        )

        var devicePayload = newJObject()
        if candidates.len > 0:
          let chosen = candidates[0]
          devicePayload[chosen.algorithm & ":" & chosen.keyId] = chosen.keyData
          state.oneTimeKeys.del(oneTimeKeyStoreKey(userId, deviceId, chosen.algorithm, chosen.keyId))
          inc state.streamPos
        else:
          var fallbackCandidates: seq[FallbackKeyRecord] = @[]
          for _, record in state.fallbackKeys:
            if record.userId == userId and record.deviceId == deviceId and
                record.algorithm == requestedAlgorithm:
              fallbackCandidates.add(record)
          fallbackCandidates.sort(proc(a, b: FallbackKeyRecord): int =
            let usedCmp = cmp(ord(a.used), ord(b.used))
            if usedCmp != 0:
              usedCmp
            else:
              let posCmp = cmp(a.streamPos, b.streamPos)
              if posCmp != 0: posCmp else: cmp(a.keyId, b.keyId)
          )
          if fallbackCandidates.len > 0:
            var chosen = fallbackCandidates[0]
            devicePayload[chosen.algorithm & ":" & chosen.keyId] = chosen.keyData
            chosen.used = true
            inc state.streamPos
            chosen.streamPos = state.streamPos
            state.fallbackKeys[oneTimeKeyStoreKey(userId, deviceId, chosen.algorithm, chosen.keyId)] = chosen

        if devicePayload.len > 0:
          userPayload[deviceId] = devicePayload
      if userPayload.len > 0:
        oneTimeKeys[userId] = userPayload

  %*{
    "one_time_keys": oneTimeKeys,
    "failures": {}
  }

proc keyChangesPayloadLocked(state: ServerState; fromToken, toToken: string): JsonNode =
  let fromPos = parseSinceToken(fromToken)
  let toPos = parseSinceToken(toToken)
  var changedSet = initHashSet[string]()

  proc inWindow(pos: int64): bool =
    if pos <= fromPos:
      return false
    toPos <= 0 or pos <= toPos

  for _, record in state.deviceKeys:
    if inWindow(record.streamPos):
      changedSet.incl(record.userId)
  for _, record in state.oneTimeKeys:
    if inWindow(record.streamPos):
      changedSet.incl(record.userId)
  for _, record in state.fallbackKeys:
    if inWindow(record.streamPos):
      changedSet.incl(record.userId)
  for _, record in state.crossSigningKeys:
    if inWindow(record.streamPos):
      changedSet.incl(record.userId)

  var changedUsers: seq[string] = @[]
  for userId in changedSet:
    changedUsers.add(userId)
  changedUsers.sort(system.cmp[string])

  var changed = newJArray()
  for userId in changedUsers:
    changed.add(%userId)
  %*{
    "changed": changed,
    "left": []
  }

proc putDehydratedDeviceLocked(
    state: ServerState;
    userId: string;
    body: JsonNode
): DehydratedDeviceRecord =
  inc state.streamPos
  let deviceId = body{"device_id"}.getStr(randomString("DEHYD", 8))
  result = DehydratedDeviceRecord(
    userId: userId,
    deviceId: deviceId,
    deviceData: if body.hasKey("device_data"): body["device_data"] else: newJObject(),
    streamPos: state.streamPos,
  )
  state.dehydratedDevices[userId] = result

proc dehydratedDevicePayload(record: DehydratedDeviceRecord): JsonNode =
  %*{
    "device_id": record.deviceId,
    "device_data": record.deviceData,
  }

proc deleteDehydratedDeviceLocked(state: ServerState; userId: string) =
  if userId in state.dehydratedDevices:
    state.dehydratedDevices.del(userId)
    inc state.streamPos

proc roomInitialSyncPayload(room: RoomData; limit: int): JsonNode =
  var chunk = newJArray()
  let maxEvents = max(0, min(limit, room.timeline.len))
  let startIdx = max(0, room.timeline.len - maxEvents)
  for idx in startIdx ..< room.timeline.len:
    chunk.add(room.timeline[idx].eventToJson())
  %*{
    "room_id": room.roomId,
    "membership": "join",
    "messages": {
      "chunk": chunk,
      "start": encodeSinceToken(0),
      "end": if room.timeline.len > 0: encodeSinceToken(room.timeline[^1].streamPos) else: encodeSinceToken(0)
    },
    "state": roomStateArray(room),
    "presence": []
  }

proc roomInitialSyncPayload(state: ServerState; room: RoomData; userId: string; limit: int): JsonNode =
  result = roomInitialSyncPayload(room, min(limit, 50))
  result["membership"] = %room.members.getOrDefault(userId, "leave")
  result["visibility"] = %(if room.roomIsPublic(): "public" else: "private")
  result["account_data"] = state.accountDataEventsForSync(userId, room.roomId, 0, true)

proc roomSummaryPayload(room: RoomData; userId = ""): JsonNode =
  result = %*{
    "room_id": room.roomId,
    "name": room.roomDisplayName(),
    "num_joined_members": room.joinedMemberCount(),
    "joined_member_count": room.joinedMemberCount(),
    "heroes": [],
    "world_readable": room.roomWorldReadable(),
    "guest_can_join": room.roomGuestCanJoin(),
    "join_rule": room.roomJoinRule(),
  }
  let aliases = room.roomAliasesPayload()
  if aliases["aliases"].len > 0:
    result["canonical_alias"] = %aliases["aliases"][0].getStr("")
  let topicKey = stateKey("m.room.topic", "")
  if topicKey in room.stateByKey:
    let content = room.stateByKey[topicKey].content
    if not content.isNil and content.kind == JObject:
      let topic = content.getOrDefault("topic").getStr("")
      if topic.len > 0:
        result["topic"] = %topic
  let createKey = stateKey("m.room.create", "")
  if createKey in room.stateByKey:
    let content = room.stateByKey[createKey].content
    if not content.isNil and content.kind == JObject:
      let roomType = content.getOrDefault("type").getStr("")
      if roomType.len > 0:
        result["room_type"] = %roomType
      let roomVersion = content.getOrDefault("room_version").getStr("")
      if roomVersion.len > 0:
        result["room_version"] = %roomVersion
  let encryptionKey = stateKey("m.room.encryption", "")
  if encryptionKey in room.stateByKey:
    result["encryption"] = room.stateByKey[encryptionKey].content
  if userId.len > 0:
    result["membership"] = %room.members.getOrDefault(userId, "leave")

proc parseSlidingSyncPos(pos: string): int64 =
  if pos.len == 0:
    return 0
  try:
    return parseInt(pos).int64
  except ValueError:
    parseSinceToken(pos)

proc jsonArrayFromStrings(values: seq[string]): JsonNode =
  result = newJArray()
  for value in values:
    result.add(%value)

proc requestedSlidingSyncRange(listReq: JsonNode; maxIndex: int): tuple[first: int, last: int] =
  result = (0, maxIndex)
  if maxIndex < 0:
    return (0, -1)
  if listReq != nil and listReq.kind == JObject and listReq.hasKey("ranges") and
      listReq["ranges"].kind == JArray and listReq["ranges"].len > 0:
    let firstRange = listReq["ranges"][0]
    if firstRange.kind == JArray and firstRange.len >= 2:
      result.first = max(0, min(maxIndex, firstRange[0].getInt(0)))
      result.last = max(result.first, min(maxIndex, firstRange[1].getInt(maxIndex)))

proc slidingSyncV5Payload(
    state: ServerState;
    userId, deviceId: string;
    request: JsonNode;
    sincePos: int64
): JsonNode =
  state.pruneExpiredTypingLocked()
  let toPos = state.streamPos
  let joinedRooms = state.joinedRoomsForUser(userId)
  var roomIds: seq[string] = @[]
  for roomId in joinedRooms:
    if roomId in state.rooms:
      roomIds.add(roomId)
  roomIds.sort(system.cmp[string])

  var roomsObj = newJObject()
  for roomId in roomIds:
    var room = state.rooms[roomId]
    discard state.ensureDefaultRoomStateLocked(roomId, userId)
    room = state.rooms[roomId]

    var timeline = newJArray()
    for ev in room.timeline:
      if ev.streamPos > sincePos:
        timeline.add(ev.eventToJson())

    var requiredState = newJArray()
    var allState: seq[MatrixEventRecord] = @[]
    for _, ev in room.stateByKey:
      allState.add(ev)
    allState.sort(proc(a, b: MatrixEventRecord): int = cmp(a.streamPos, b.streamPos))
    for ev in allState:
      requiredState.add(ev.eventToJson())

    var invitedCount = 0
    for _, membership in room.members:
      if membership == "invite":
        inc invitedCount

    roomsObj[roomId] = %*{
      "name": room.roomDisplayName(),
      "is_dm": room.isDirect,
      "initial": sincePos == 0,
      "joined_count": room.joinedMemberCount(),
      "invited_count": invitedCount,
      "notification_count": 0,
      "highlight_count": 0,
      "timeline": timeline,
      "required_state": requiredState,
      "prev_batch": encodeSinceToken(sincePos),
      "limited": false,
      "num_live": timeline.len,
      "bump_stamp": toPos,
    }
  var listsObj = newJObject()
  let listsReq = if request != nil and request.kind == JObject and request.hasKey("lists") and
      request["lists"].kind == JObject: request["lists"] else: newJObject()
  if listsReq.len == 0:
    let highIndex = roomIds.len - 1
    let rangeJson = if highIndex >= 0: %*[0, highIndex] else: %*[0, 0]
    listsObj["main"] = %*{
      "count": roomIds.len,
      "ops": [
        {
          "op": "SYNC",
          "range": rangeJson,
          "room_ids": jsonArrayFromStrings(roomIds)
        }
      ]
    }
  else:
    for listId, listReq in listsReq:
      let selectedRange = requestedSlidingSyncRange(listReq, roomIds.len - 1)
      var selected: seq[string] = @[]
      if selectedRange.last >= selectedRange.first:
        for idx in selectedRange.first .. selectedRange.last:
          if idx >= 0 and idx < roomIds.len:
            selected.add(roomIds[idx])
      listsObj[listId] = %*{
        "count": roomIds.len,
        "ops": [
          {
            "op": "SYNC",
            "range": [selectedRange.first, max(selectedRange.first, selectedRange.last)],
            "room_ids": jsonArrayFromStrings(selected)
          }
        ]
      }

  let removedToDevice = state.removeToDeviceEventsLocked(userId, deviceId, sincePos)
  let toDeviceEvents = state.toDeviceEventsForSync(userId, deviceId, sincePos, toPos)
  if removedToDevice:
    state.savePersistentState()

  let txnId =
    if request != nil and request.kind == JObject: request{"txn_id"}.getStr("")
    else: ""
  result = %*{
    "pos": $toPos,
    "lists": listsObj,
    "rooms": roomsObj,
    "extensions": {
      "to_device": {
        "next_batch": $toPos,
        "events": toDeviceEvents
      },
      "e2ee": {
        "device_one_time_keys_count": state.oneTimeKeyCountsLocked(userId, deviceId),
        "device_unused_fallback_key_types": state.unusedFallbackKeyTypesLocked(userId, deviceId)
      },
      "account_data": {
        "global": state.accountDataEventsForSync(userId, "", sincePos, sincePos == 0),
        "rooms": {}
      },
      "receipts": {
        "rooms": {}
      },
      "typing": {
        "rooms": {}
      }
    }
  }
  if txnId.len > 0:
    result["txn_id"] = %txnId

proc roomHierarchyPayload(
    state: ServerState;
    rootRoomId, userId: string
): tuple[ok: bool, forbidden: bool, payload: JsonNode] =
  if rootRoomId notin state.rooms:
    return (false, false, newJObject())
  if not state.roomVisibleToUser(rootRoomId, userId):
    return (false, true, newJObject())

  let root = state.rooms[rootRoomId]
  var rooms = newJArray()
  var childrenState = newJArray()
  var childIds: seq[string] = @[]
  var seenChildren = initHashSet[string]()
  for _, ev in root.stateByKey:
    if ev.eventType != "m.space.child" or ev.stateKey.len == 0:
      continue
    childrenState.add(ev.eventToJson())
    if ev.stateKey notin seenChildren:
      childIds.add(ev.stateKey)
      seenChildren.incl(ev.stateKey)
  childIds.sort(system.cmp[string])

  var rootSummary = roomSummaryPayload(root, userId)
  rootSummary["children_state"] = childrenState
  rooms.add(rootSummary)

  for childId in childIds:
    if childId notin state.rooms or not state.roomVisibleToUser(childId, userId):
      continue
    rooms.add(roomSummaryPayload(state.rooms[childId], userId))

  (true, false, %*{"rooms": rooms, "next_batch": ""})

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

proc upgradeRoomLocked(
    state: ServerState;
    roomId, userId, requestedVersion: string
): tuple[ok: bool, forbidden: bool, replacementRoom: string] =
  if roomId notin state.rooms:
    return (false, false, "")
  if not state.roomJoinedForUser(roomId, userId):
    return (true, true, "")

  let oldRoom = state.rooms[roomId]
  let replacementRoom = state.nextRoomId()
  state.rooms[replacementRoom] = RoomData(
    roomId: replacementRoom,
    creator: userId,
    isDirect: oldRoom.isDirect,
    members: initTable[string, string](),
    timeline: @[],
    stateByKey: initTable[string, MatrixEventRecord]()
  )

  var createContent = %*{
    "creator": userId,
    "room_version": if requestedVersion.len > 0: requestedVersion else: "11"
  }
  let oldCreateKey = stateKey("m.room.create", "")
  if oldCreateKey in oldRoom.stateByKey:
    let oldCreate = oldRoom.stateByKey[oldCreateKey].content
    if not oldCreate.isNil and oldCreate.kind == JObject:
      let roomType = oldCreate.getOrDefault("type").getStr("")
      if roomType.len > 0:
        createContent["type"] = %roomType

  let createEvent = state.appendEventLocked(replacementRoom, userId, "m.room.create", "", createContent)
  state.enqueueEventDeliveries(createEvent)
  let powerEvent = state.appendEventLocked(replacementRoom, userId, "m.room.power_levels", "", defaultPowerLevelsContent(userId))
  state.enqueueEventDeliveries(powerEvent)

  var copiedState: seq[MatrixEventRecord] = @[]
  for _, ev in oldRoom.stateByKey:
    if ev.eventType in ["m.room.create", "m.room.member", "m.room.power_levels", "m.room.tombstone"]:
      continue
    copiedState.add(ev)
  copiedState.sort(proc(a, b: MatrixEventRecord): int =
    let posCmp = cmp(a.streamPos, b.streamPos)
    if posCmp != 0: posCmp else: cmp(a.eventType & a.stateKey, b.eventType & b.stateKey)
  )
  for ev in copiedState:
    let copied = state.appendEventLocked(replacementRoom, userId, ev.eventType, ev.stateKey, ev.content)
    state.enqueueEventDeliveries(copied)

  var joinedUsers: seq[string] = @[]
  for memberId, membership in oldRoom.members:
    if membership == "join":
      joinedUsers.add(memberId)
  joinedUsers.sort(system.cmp[string])
  for memberId in joinedUsers:
    let memberEvent = state.appendEventLocked(
      replacementRoom,
      if memberId == userId: userId else: userId,
      "m.room.member",
      memberId,
      membershipContent("join")
    )
    state.enqueueEventDeliveries(memberEvent)

  let tombstone = state.appendEventLocked(
    roomId,
    userId,
    "m.room.tombstone",
    "",
    %*{
      "body": "This room has been replaced.",
      "replacement_room": replacementRoom
    }
  )
  state.enqueueEventDeliveries(tombstone)

  (true, false, replacementRoom)

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

proc enqueueEventDeliveries(state: ServerState; ev: MatrixEventRecord) {.gcsafe.} =
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

{.push warning[Uninit]: off.}
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
{.pop.}

{.push warning[Uninit]: off.}
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
{.pop.}

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
    path.startsWith("/_matrix/media/r0/preview_url") or
    path.startsWith("/_matrix/media/v1/preview_url") or
    path.startsWith("/_matrix/client/v1/media/preview_url")

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

proc methodNotAllowed(req: Request): Future[void] =
  respondJson(req, Http405, matrixError("M_UNRECOGNIZED", "Method Not Allowed"))

proc notFound(req: Request): Future[void] =
  respondJson(req, Http404, matrixError("M_UNRECOGNIZED", "Not Found"))

proc notFoundWithCode(req: Request; errcode: string): Future[void] =
  respondJson(req, Http404, matrixError(errcode, "Not Found"))

proc parseRequestJson(req: Request): tuple[ok: bool, value: JsonNode] =
  if req.body.len == 0:
    return (true, newJObject())
  try:
    let parsed = parseJson(req.body)
    (true, parsed)
  except CatchableError:
    (false, newJObject())

proc firstJsonString(node: JsonNode; keys: openArray[string]): string =
  if node.kind != JObject:
    return ""
  for key in keys:
    if node.hasKey(key) and node[key].kind == JString:
      let value = node[key].getStr("")
      if value.len > 0:
        return value
  ""

proc trimClientPath(path: string): string =
  if path.startsWith("/_matrix/client/v3/"):
    return path["/_matrix/client/v3/".len .. ^1]
  if path.startsWith("/_matrix/client/r0/"):
    return path["/_matrix/client/r0/".len .. ^1]
  ""

proc trimAccountDataClientPath(path: string): string =
  result = trimClientPath(path)
  if result.len > 0:
    return
  const UnstablePrefix = "/_matrix/client/unstable/org.matrix.msc3391/"
  if path.startsWith(UnstablePrefix):
    return path[UnstablePrefix.len .. ^1]
  return ""

proc decodePath(value: string): string =
  try:
    decodeUrl(value)
  except CatchableError:
    value

proc pushRulePathParts(path: string): tuple[
    ok: bool,
    scope: string,
    kind: string,
    ruleId: string,
    attr: string
] =
  result = (false, "", "", "", "")
  let parts = trimClientPath(path).split("/")
  if parts.len == 1 and parts[0] == "pushrules":
    return (true, "", "", "", "")
  if parts.len == 2 and parts[0] == "pushrules":
    return (true, decodePath(parts[1]), "", "", "")
  if parts.len == 3 and parts[0] == "pushrules":
    return (true, decodePath(parts[1]), decodePath(parts[2]), "", "")
  if parts.len == 4 and parts[0] == "pushrules":
    return (true, decodePath(parts[1]), decodePath(parts[2]), decodePath(parts[3]), "")
  if parts.len == 5 and parts[0] == "pushrules":
    return (true, decodePath(parts[1]), decodePath(parts[2]), decodePath(parts[3]), decodePath(parts[4]))

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

proc roomTypingPathParts(path: string): tuple[ok: bool, roomId: string, userId: string] =
  result = (false, "", "")
  let trimmed = trimClientPath(path)
  if trimmed.len == 0:
    return
  let parts = trimmed.split("/")
  if parts.len == 4 and parts[0] == "rooms" and parts[2] == "typing":
    return (true, decodePath(parts[1]), decodePath(parts[3]))

proc roomReceiptPathParts(path: string): tuple[ok: bool, roomId: string, receiptType: string, eventId: string] =
  result = (false, "", "", "")
  let trimmed = trimClientPath(path)
  if trimmed.len == 0:
    return
  let parts = trimmed.split("/")
  if parts.len == 5 and parts[0] == "rooms" and parts[2] == "receipt":
    return (true, decodePath(parts[1]), decodePath(parts[3]), decodePath(parts[4]))

proc roomReadMarkersPathParts(path: string): tuple[ok: bool, roomId: string] =
  let roomId = roomIdFromRoomsPath(path, "read_markers")
  (roomId.len > 0, roomId)

proc userFilterPathParts(path: string): tuple[ok: bool, userId: string, filterId: string, create: bool] =
  result = (false, "", "", false)
  let trimmed = trimClientPath(path)
  if trimmed.len == 0:
    return
  let parts = trimmed.split("/")
  if parts.len == 3 and parts[0] == "user" and parts[2] == "filter":
    return (true, decodePath(parts[1]), "", true)
  if parts.len == 4 and parts[0] == "user" and parts[2] == "filter":
    return (true, decodePath(parts[1]), decodePath(parts[3]), false)

proc userAccountDataPathParts(path: string): tuple[ok: bool, userId: string, roomId: string, eventType: string] =
  result = (false, "", "", "")
  let trimmed = trimAccountDataClientPath(path)
  if trimmed.len == 0:
    return
  let parts = trimmed.split("/")
  if parts.len >= 4 and parts[0] == "user" and parts[2] == "account_data":
    return (true, decodePath(parts[1]), "", decodePath(parts[3 .. ^1].join("/")))
  if parts.len >= 6 and parts[0] == "user" and parts[2] == "rooms" and parts[4] == "account_data":
    return (true, decodePath(parts[1]), decodePath(parts[3]), decodePath(parts[5 .. ^1].join("/")))

proc userTagsPathParts(path: string): tuple[ok: bool, userId: string, roomId: string, tag: string, collection: bool] =
  result = (false, "", "", "", false)
  let trimmed = trimClientPath(path)
  if trimmed.len == 0:
    return
  let parts = trimmed.split("/")
  if parts.len == 5 and parts[0] == "user" and parts[2] == "rooms" and parts[4] == "tags":
    return (true, decodePath(parts[1]), decodePath(parts[3]), "", true)
  if parts.len >= 6 and parts[0] == "user" and parts[2] == "rooms" and parts[4] == "tags":
    return (true, decodePath(parts[1]), decodePath(parts[3]), decodePath(parts[5 .. ^1].join("/")), false)

proc devicePathParts(path: string): tuple[ok: bool, deviceId: string, collection: bool] =
  result = (false, "", false)
  let trimmed = trimClientPath(path)
  if trimmed == "devices":
    return (true, "", true)
  let parts = trimmed.split("/")
  if parts.len == 2 and parts[0] == "devices":
    return (true, decodePath(parts[1]), false)

proc deleteDevicesPath(path: string): bool =
  trimClientPath(path) == "delete_devices"

proc mediaDownloadParts(path: string): tuple[ok: bool, mediaId: string] =
  let normalized = path.strip()
  let markers = [
    "/_matrix/media/v3/download/",
    "/_matrix/media/v3/thumbnail/",
    "/_matrix/media/r0/download/",
    "/_matrix/media/r0/thumbnail/",
    "/_matrix/media/v1/download/",
    "/_matrix/media/v1/thumbnail/",
    "/_matrix/client/v1/media/download/",
    "/_matrix/client/v1/media/thumbnail/"
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

proc roomAndEventFromPath(path: string; marker: string): tuple[roomId: string, eventId: string] =
  let trimmed = trimClientPath(path)
  if not trimmed.startsWith("rooms/"):
    return ("", "")
  let segments = trimmed.split('/')
  if segments.len != 4:
    return ("", "")
  if segments[2] != marker:
    return ("", "")
  (decodePath(segments[1]), decodePath(segments[3]))

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
  var trimmed = trimClientPath(path)
  if trimmed.len == 0:
    const UnstableProfilePrefixes = [
      "/_matrix/client/unstable/uk.tcpip.msc4133/profile/",
      "/_matrix/client/unstable/us.cloke.msc4175/profile/"
    ]
    for prefix in UnstableProfilePrefixes:
      if path.startsWith(prefix):
        trimmed = "profile/" & path[prefix.len .. ^1]
        break
  if not trimmed.startsWith("profile/"):
    return ("", "")
  let segments = trimmed.split('/')
  if segments.len < 2:
    return ("", "")
  let userId = decodePath(segments[1])
  let field = if segments.len >= 3: decodePath(segments[2 .. ^1].join("/")) else: ""
  (userId, field)

proc presencePathParts(path: string): tuple[ok: bool, userId: string] =
  result = (false, "")
  let trimmed = trimClientPath(path)
  if trimmed.len == 0:
    return
  let parts = trimmed.split("/")
  if parts.len == 3 and parts[0] == "presence" and parts[2] == "status":
    return (true, decodePath(parts[1]))

proc isJoinedRoomsPath(path: string): bool =
  trimClientPath(path) == "joined_rooms"

proc isThirdPartyProtocolsPath(path: string): bool =
  let trimmed = trimClientPath(path)
  trimmed == "thirdparty/protocols" or trimmed.startsWith("thirdparty/protocol/")

proc isTurnServerPath(path: string): bool =
  trimClientPath(path) == "voip/turnServer"

proc isAccount3pidPath(path: string): bool =
  trimClientPath(path) == "account/3pid"

proc isChangePasswordPath(path: string): bool =
  trimClientPath(path) == "account/password"

proc isDeactivatePath(path: string): bool =
  trimClientPath(path) == "account/deactivate"

proc isRequest3pidManagementTokenPath(path: string): bool =
  let trimmed = trimClientPath(path)
  trimmed == "account/3pid/email/requestToken" or
    trimmed == "account/3pid/msisdn/requestToken"

proc isRefreshTokenPath(path: string): bool =
  trimClientPath(path) == "refresh"

proc isRegistrationTokenValidityPath(path: string): bool =
  path == "/_matrix/client/v1/register/m.login.registration_token/validity" or
    trimClientPath(path) == "register/m.login.registration_token/validity"

proc isLoginTokenPath(path: string): bool =
  path == "/_matrix/client/v1/login/get_token" or
    trimClientPath(path) == "login/get_token"

proc isNotificationsPath(path: string): bool =
  trimClientPath(path) == "notifications"

proc isPushersPath(path: string): bool =
  trimClientPath(path) == "pushers"

proc isPushRulesPath(path: string): bool =
  let trimmed = trimClientPath(path)
  trimmed == "pushrules" or trimmed == "pushrules/" or trimmed.startsWith("pushrules/")

proc isKeysQueryPath(path: string): bool =
  trimClientPath(path) == "keys/query"

proc isKeysClaimPath(path: string): bool =
  trimClientPath(path) == "keys/claim"

proc isKeysUploadPath(path: string): bool =
  trimClientPath(path) == "keys/upload"

proc isKeysChangesPath(path: string): bool =
  trimClientPath(path).startsWith("keys/changes")

proc isSigningKeyUploadPath(path: string): bool =
  let trimmed = trimClientPath(path)
  trimmed == "keys/device_signing/upload" or trimmed == "keys/signatures/upload"

proc signingKeyUploadKind(path: string): string =
  case trimClientPath(path)
  of "keys/device_signing/upload":
    "device_signing"
  of "keys/signatures/upload":
    "signatures"
  else:
    ""

proc isSearchPath(path: string): bool =
  trimClientPath(path) == "search"

proc isUserDirectorySearchPath(path: string): bool =
  trimClientPath(path) == "user_directory/search"

proc openIdPathParts(path: string): tuple[ok: bool, userId: string] =
  result = (false, "")
  let parts = trimClientPath(path).split("/")
  if parts.len == 4 and parts[0] == "user" and parts[2] == "openid" and parts[3] == "request_token":
    return (true, decodePath(parts[1]))

proc sendToDevicePathParts(path: string): tuple[ok: bool, eventType: string, txnId: string] =
  result = (false, "", "")
  let parts = trimClientPath(path).split("/")
  if parts.len == 3 and parts[0] == "sendToDevice":
    return (true, decodePath(parts[1]), decodePath(parts[2]))

proc directoryAliasPathParts(path: string): tuple[ok: bool, alias: string] =
  result = (false, "")
  let parts = trimClientPath(path).split("/")
  if parts.len >= 3 and parts[0] == "directory" and parts[1] == "room":
    return (true, decodePath(parts[2 .. ^1].join("/")))

proc roomVisibilityPathParts(path: string): tuple[ok: bool, roomId: string] =
  result = (false, "")
  let parts = trimClientPath(path).split("/")
  if parts.len >= 4 and parts[0] == "directory" and parts[1] == "list" and parts[2] == "room":
    return (true, decodePath(parts[3 .. ^1].join("/")))

proc reportPathParts(path: string): tuple[ok: bool, roomId: string, eventId: string] =
  result = (false, "", "")
  let parts = trimClientPath(path).split("/")
  if parts.len == 3 and parts[0] == "rooms" and parts[2] == "report":
    return (true, decodePath(parts[1]), "")
  if parts.len == 4 and parts[0] == "rooms" and parts[2] == "report":
    return (true, decodePath(parts[1]), decodePath(parts[3]))

proc knockTargetFromPath(path: string): string =
  let trimmed = trimClientPath(path)
  if trimmed.startsWith("knock/"):
    return decodePath(trimmed["knock/".len .. ^1])
  roomIdFromRoomsPath(path, "knock")

proc roomInitialSyncId(path: string): string =
  roomIdFromRoomsPath(path, "initialSync")

proc unstableSummaryRoomId(path: string): string =
  const Prefix = "/_matrix/client/unstable/im.nheko.summary/rooms/"
  const Suffix = "/summary"
  if path.startsWith(Prefix) and path.endsWith(Suffix):
    return decodePath(path[Prefix.len ..< path.len - Suffix.len])
  let trimmed = trimClientPath(path)
  let parts = trimmed.split("/")
  if parts.len == 4 and parts[0] == "rooms" and parts[2] == "summary":
    return decodePath(parts[1])
  ""

proc relationRoomId(path: string): string =
  let parts = trimClientPath(path).split("/")
  if parts.len >= 4 and parts[0] == "rooms" and parts[2] == "relations":
    return decodePath(parts[1])
  ""

proc relationPathParts(path: string): tuple[
    ok: bool,
    roomId: string,
    eventId: string,
    relType: string,
    eventType: string
] =
  result = (false, "", "", "", "")
  let parts = trimClientPath(path).split("/")
  if parts.len < 4 or parts.len > 6:
    return
  if parts[0] != "rooms" or parts[2] != "relations":
    return
  result.ok = true
  result.roomId = decodePath(parts[1])
  result.eventId = decodePath(parts[3])
  if parts.len >= 5:
    result.relType = decodePath(parts[4])
  if parts.len >= 6:
    result.eventType = decodePath(parts[5])

proc threadsRoomId(path: string): string =
  roomIdFromRoomsPath(path, "threads")

proc hierarchyRoomId(path: string): string =
  roomIdFromRoomsPath(path, "hierarchy")

proc upgradeRoomId(path: string): string =
  roomIdFromRoomsPath(path, "upgrade")

proc mutualRoomsUserId(path: string): string =
  let parts = trimClientPath(path).split("/")
  if parts.len == 3 and parts[0] == "user" and parts[2] == "mutual_rooms":
    return decodePath(parts[1])
  ""

proc roomKeysPathKind(path: string): string =
  let trimmed = trimClientPath(path)
  if trimmed == "room_keys/version" or trimmed.startsWith("room_keys/version/"):
    return "version"
  if trimmed == "room_keys/keys" or trimmed.startsWith("room_keys/keys/"):
    return "keys"
  ""

proc roomKeysPathParts(path: string): tuple[ok: bool, kind: string, version: string, roomId: string, sessionId: string] =
  result = (false, "", "", "", "")
  let parts = trimClientPath(path).split("/")
  if parts.len < 2 or parts[0] != "room_keys":
    return
  case parts[1]
  of "version":
    if parts.len == 2:
      return (true, "version", "", "", "")
    if parts.len == 3:
      return (true, "version", decodePath(parts[2]), "", "")
  of "keys":
    if parts.len == 2:
      return (true, "keys", "", "", "")
    if parts.len == 3:
      return (true, "keys", "", decodePath(parts[2]), "")
    if parts.len >= 4:
      return (true, "keys", "", decodePath(parts[2]), decodePath(parts[3 .. ^1].join("/")))
  else:
    discard

proc dehydratedDevicePathParts(path: string): tuple[ok: bool, events: bool, deviceId: string] =
  var trimmed = trimClientPath(path)
  if trimmed.len == 0:
    const UnstablePrefixes = [
      "/_matrix/client/unstable/org.matrix.msc2697.v2/",
      "/_matrix/client/unstable/org.matrix.msc2697/"
    ]
    for prefix in UnstablePrefixes:
      if path.startsWith(prefix):
        trimmed = path[prefix.len .. ^1]
        break
  let needle = "dehydrated_device"
  let idx = trimmed.find(needle)
  if idx < 0:
    return (false, false, "")
  let suffixStart = idx + needle.len
  if suffixStart >= trimmed.len:
    return (true, false, "")
  var suffix = trimmed[suffixStart .. ^1].strip(chars = {'/'})
  if suffix.len == 0:
    return (true, false, "")
  let parts = suffix.split("/")
  if parts.len == 2 and parts[1] == "events":
    return (true, true, decodePath(parts[0]))
  (true, false, decodePath(parts[0]))

proc trimFederationPath(path: string): string =
  const Prefixes = [
    "/_matrix/federation/v1/",
    "/_matrix/federation/v2/",
  ]
  for prefix in Prefixes:
    if path.startsWith(prefix):
      return path[prefix.len .. ^1]
  ""

proc federationPathParts(path: string): seq[string] =
  result = @[]
  let trimmed = trimFederationPath(path)
  if trimmed.len == 0:
    return
  for part in trimmed.split('/'):
    result.add(decodePath(part))

proc federationMediaPathParts(path: string): tuple[ok: bool, thumbnail: bool, mediaId: string] =
  let parts = federationPathParts(path)
  if parts.len == 3 and parts[0] == "media" and parts[1] in ["download", "thumbnail"]:
    return (parts[2].len > 0, parts[1] == "thumbnail", parts[2])
  (false, false, "")

proc findEventLocked(
    state: ServerState;
    eventId: string
): tuple[ok: bool, roomId: string, event: MatrixEventRecord, index: int] =
  for roomId, room in state.rooms:
    for idx, ev in room.timeline:
      if ev.eventId == eventId:
        return (true, roomId, ev, idx)
  (false, "", MatrixEventRecord(), -1)

proc roomStateEvents(room: RoomData): seq[MatrixEventRecord] =
  result = @[]
  for _, ev in room.stateByKey:
    result.add(ev)
  result.sort(proc(a, b: MatrixEventRecord): int = cmp(a.streamPos, b.streamPos))

proc roomStateEventIds(room: RoomData): JsonNode =
  result = newJArray()
  for ev in room.roomStateEvents():
    result.add(%ev.eventId)

proc federationVersionPayload(): JsonNode =
  %*{
    "server": {
      "name": "Tuwunel",
      "version": RustBaselineVersion,
      "compiler": "nim"
    }
  }

proc federationOpenIdUserInfoPayload(
    state: ServerState;
    accessToken: string
): tuple[ok: bool, payload: JsonNode] =
  if accessToken.len == 0 or accessToken notin state.openIdTokens:
    return (false, newJObject())
  let record = state.openIdTokens[accessToken]
  if record.expiresAtMs <= nowMs():
    state.openIdTokens.del(accessToken)
    return (false, newJObject())
  (true, %*{"sub": record.userId})

proc federationEventPayload(
    state: ServerState;
    eventId: string
): tuple[ok: bool, payload: JsonNode] =
  let found = state.findEventLocked(eventId)
  if not found.ok:
    return (false, newJObject())
  (true, %*{
    "origin": state.serverName,
    "origin_server_ts": nowMs(),
    "pdu": found.event.eventToJson()
  })

proc federationRoomStatePayload(
    state: ServerState;
    roomId, eventId: string;
    idsOnly: bool
): tuple[ok: bool, eventKnown: bool, payload: JsonNode] =
  if roomId notin state.rooms:
    return (false, false, newJObject())
  let room = state.rooms[roomId]
  if eventId.len > 0 and roomEventIndex(room, eventId) < 0:
    return (true, false, newJObject())

  if idsOnly:
    return (true, true, %*{
      "auth_chain_ids": [],
      "pdu_ids": room.roomStateEventIds()
    })

  (true, true, %*{
    "auth_chain": [],
    "pdus": roomStateArray(room)
  })

proc federationBackfillPayload(
    state: ServerState;
    roomId: string;
    fromEventIds: seq[string];
    limit: int
): tuple[ok: bool, payload: JsonNode] =
  if roomId notin state.rooms:
    return (false, newJObject())
  let room = state.rooms[roomId]
  var fromPos = high(int64)
  for eventId in fromEventIds:
    let idx = roomEventIndex(room, eventId)
    if idx >= 0:
      fromPos = min(fromPos, room.timeline[idx].streamPos)
  if fromPos == high(int64):
    if room.timeline.len == 0:
      fromPos = 0
    else:
      fromPos = room.timeline[^1].streamPos + 1

  let cappedLimit = max(0, min(150, limit))
  var pdus = newJArray()
  if cappedLimit > 0:
    for idx in countdown(room.timeline.high, 0):
      let ev = room.timeline[idx]
      if ev.streamPos >= fromPos:
        continue
      pdus.add(ev.eventToJson())
      if pdus.len >= cappedLimit:
        break

  (true, %*{
    "origin": state.serverName,
    "origin_server_ts": nowMs(),
    "pdus": pdus
  })

proc federationMissingEventsPayload(
    state: ServerState;
    roomId: string;
    body: JsonNode
): tuple[ok: bool, payload: JsonNode] =
  if roomId notin state.rooms:
    return (false, newJObject())
  let room = state.rooms[roomId]
  let limit = max(0, min(100, body{"limit"}.getInt(10)))
  var earliestPos = 0'i64
  if body{"earliest_events"}.kind == JArray:
    for node in body["earliest_events"]:
      let idx = roomEventIndex(room, node.getStr(""))
      if idx >= 0:
        earliestPos = max(earliestPos, room.timeline[idx].streamPos)

  var latestPos = high(int64)
  if body{"latest_events"}.kind == JArray:
    for node in body["latest_events"]:
      let idx = roomEventIndex(room, node.getStr(""))
      if idx >= 0:
        latestPos = min(latestPos, room.timeline[idx].streamPos)

  var events = newJArray()
  for ev in room.timeline:
    if ev.streamPos <= earliestPos or ev.streamPos >= latestPos:
      continue
    events.add(ev.eventToJson())
    if events.len >= limit:
      break

  (true, %*{"events": events})

proc federationEventAuthPayload(
    state: ServerState;
    roomId, eventId: string
): tuple[ok: bool, eventKnown: bool, payload: JsonNode] =
  if roomId notin state.rooms:
    return (false, false, newJObject())
  let room = state.rooms[roomId]
  if roomEventIndex(room, eventId) < 0:
    return (true, false, newJObject())
  var authChain = newJArray()
  for ev in room.roomStateEvents():
    if ev.eventId != eventId:
      authChain.add(ev.eventToJson())
  (true, true, %*{"auth_chain": authChain})

proc federationDirectoryPayload(
    state: ServerState;
    roomAlias, serverName: string
): tuple[ok: bool, payload: JsonNode] =
  let roomId = state.findRoomByAliasLocked(roomAlias)
  if roomId.len == 0:
    return (false, newJObject())
  (true, %*{"room_id": roomId, "servers": [serverName]})

proc federationProfilePayload(
    state: ServerState;
    userId, field: string
): tuple[ok: bool, payload: JsonNode] =
  if userId notin state.users:
    return (false, newJObject())
  if field.len == 0:
    return (true, userProfilePayload(state.users[userId]))
  profileFieldPayload(state.users[userId], field)

proc federationUserDevicesPayload(
    state: ServerState;
    userId: string
): tuple[ok: bool, payload: JsonNode] =
  if userId notin state.users:
    return (false, newJObject())
  var devices = newJArray()
  var records: seq[DeviceRecord] = @[]
  for _, device in state.devices:
    if device.userId == userId:
      records.add(device)
  records.sort(proc(a, b: DeviceRecord): int = cmp(a.deviceId, b.deviceId))
  for device in records:
    let key = deviceKey(userId, device.deviceId)
    let displayName = if device.displayName.len > 0: device.displayName else: device.deviceId
    let keyPayload = if key in state.deviceKeys: state.deviceKeys[key].keyData else: deviceKeyPayload(userId, device)
    var entry = newJObject()
    entry["device_id"] = %device.deviceId
    entry["device_display_name"] = %displayName
    entry["keys"] = keyPayload
    devices.add(entry)
  result = (true, %*{
    "user_id": userId,
    "stream_id": state.streamPos,
    "devices": devices
  })
  let masterKey = crossSigningKey(userId, "master")
  if masterKey in state.crossSigningKeys:
    result.payload["master_key"] = state.crossSigningKeys[masterKey].keyData
  let selfSigningKey = crossSigningKey(userId, "self_signing")
  if selfSigningKey in state.crossSigningKeys:
    result.payload["self_signing_key"] = state.crossSigningKeys[selfSigningKey].keyData

proc roomVersion(room: RoomData): string =
  let createKey = stateKey("m.room.create", "")
  if createKey in room.stateByKey:
    let content = room.stateByKey[createKey].content
    if not content.isNil and content.kind == JObject:
      let version = content{"room_version"}.getStr("")
      if version.len > 0:
        return version
  "11"

proc membershipTemplateEvent(
    state: ServerState;
    roomId, userId, membership, origin: string
): tuple[ok: bool, payload: JsonNode] =
  if roomId notin state.rooms:
    return (false, newJObject())
  let room = state.rooms[roomId]
  let eventId = "$template_" & randomString("", 12)
  var event = %*{
    "event_id": eventId,
    "room_id": roomId,
    "sender": userId,
    "type": "m.room.member",
    "state_key": userId,
    "origin": if origin.len > 0: origin else: state.serverName,
    "origin_server_ts": nowMs(),
    "content": {
      "membership": membership
    },
    "auth_events": [],
    "prev_events": []
  }
  (true, %*{
    "room_version": room.roomVersion(),
    "event": event
  })

proc appendFederationPduLocked(
    state: ServerState;
    pdu: JsonNode;
    fallbackRoomId, fallbackEventId, fallbackSender, fallbackType, membershipOverride: string
): tuple[ok: bool, event: MatrixEventRecord, errcode: string, message: string] =
  if pdu.kind != JObject:
    return (false, MatrixEventRecord(), "M_BAD_JSON", "PDU must be an object.")

  let roomId = pdu{"room_id"}.getStr(fallbackRoomId)
  if roomId.len == 0:
    return (false, MatrixEventRecord(), "M_BAD_JSON", "PDU is missing room_id.")
  if roomId notin state.rooms:
    return (false, MatrixEventRecord(), "M_NOT_FOUND", "Room is unknown to this server.")

  let eventType = pdu{"type"}.getStr(fallbackType)
  if eventType.len == 0:
    return (false, MatrixEventRecord(), "M_BAD_JSON", "PDU is missing type.")

  let sender = pdu{"sender"}.getStr(fallbackSender)
  if sender.len == 0:
    return (false, MatrixEventRecord(), "M_BAD_JSON", "PDU is missing sender.")

  let stateKeyValue =
    if pdu.hasKey("state_key") and pdu["state_key"].kind == JString:
      pdu["state_key"].getStr("")
    else:
      ""
  var content =
    if pdu.hasKey("content") and pdu["content"].kind == JObject:
      pdu["content"].copy()
    else:
      newJObject()
  if eventType == "m.room.member" and membershipOverride.len > 0 and
      content{"membership"}.getStr("").len == 0:
    content["membership"] = %membershipOverride

  let eventId =
    block:
      let candidate = pdu{"event_id"}.getStr(fallbackEventId)
      if candidate.len > 0: candidate else: "$" & $state.streamPos & "_" & randomString("", 8)
  let redacts =
    block:
      let top = pdu{"redacts"}.getStr("")
      if top.len > 0: top else: content{"redacts"}.getStr("")
  let ts = pdu{"origin_server_ts"}.getInt(nowMs().int).int64

  var room = state.rooms[roomId]
  inc state.streamPos
  let ev = MatrixEventRecord(
    streamPos: state.streamPos,
    eventId: eventId,
    roomId: roomId,
    sender: sender,
    eventType: eventType,
    stateKey: stateKeyValue,
    redacts: redacts,
    originServerTs: ts,
    content: content,
  )
  room.timeline.add(ev)
  if isStateEventForStorage(eventType, stateKeyValue):
    room.stateByKey[stateKey(eventType, stateKeyValue)] = ev
  if eventType == "m.room.member" and stateKeyValue.len > 0:
    let membership = content{"membership"}.getStr("")
    if membership.len > 0:
      state.applyMembership(room, stateKeyValue, membership)
  state.rooms[roomId] = room
  state.enqueueEventDeliveries(ev)
  (true, ev, "", "")

proc federationSendTransactionLocked(
    state: ServerState;
    origin, txnId: string;
    body: JsonNode
): JsonNode =
  var pduResults = newJObject()
  let pdus = body{"pdus"}
  if pdus.kind == JArray:
    for pdu in pdus:
      let fallbackId = pdu{"event_id"}.getStr("$txn_" & txnId & "_" & $pduResults.len)
      let appended = state.appendFederationPduLocked(pdu, "", fallbackId, "", "", "")
      if appended.ok:
        pduResults[appended.event.eventId] = %*{}
      else:
        pduResults[fallbackId] = matrixError(appended.errcode, appended.message)

  let edus = body{"edus"}
  if edus.kind == JArray:
    for edu in edus:
      if edu.kind != JObject:
        continue
      let eduType = edu{"edu_type"}.getStr(edu{"type"}.getStr(""))
      let content =
        if edu.hasKey("content") and edu["content"].kind == JObject:
          edu["content"]
        else:
          edu
      case eduType
      of "m.typing":
        let roomId = content{"room_id"}.getStr("")
        let userId = content{"user_id"}.getStr("")
        if roomId.len > 0 and userId.len > 0 and roomId in state.rooms:
          state.setTypingLocked(roomId, userId, content{"typing"}.getBool(false), 30000)
      of "m.presence":
        let push = content{"push"}
        if push.kind == JArray:
          for update in push:
            let userId = update{"user_id"}.getStr("")
            let presence = update{"presence"}.getStr("online").toLowerAscii()
            if userId.len > 0 and isValidPresenceValue(presence):
              discard state.setPresenceLocked(userId, presence, update{"status_msg"}.getStr(""))
      else:
        discard

  %*{"pdus": pduResults}

proc federationAcceptMembershipLocked(
    state: ServerState;
    roomId, eventId, expectedMembership: string;
    body: JsonNode
): tuple[ok: bool, payload: JsonNode, errcode: string, message: string] =
  if roomId notin state.rooms:
    return (false, newJObject(), "M_NOT_FOUND", "Room is unknown to this server.")
  let pdu =
    if body.hasKey("pdu") and body["pdu"].kind == JObject:
      body["pdu"]
    elif body.hasKey("event") and body["event"].kind == JObject:
      body["event"]
    else:
      body
  let sender = pdu{"sender"}.getStr(pdu{"state_key"}.getStr(""))
  let appended = state.appendFederationPduLocked(
    pdu,
    roomId,
    eventId,
    sender,
    "m.room.member",
    expectedMembership,
  )
  if not appended.ok:
    return (false, newJObject(), appended.errcode, appended.message)

  case expectedMembership
  of "join":
    let room = state.rooms[roomId]
    return (true, %*{
      "state": roomStateArray(room),
      "auth_chain": [],
      "event": appended.event.eventToJson(),
      "members_omitted": false,
      "origin": state.serverName
    }, "", "")
  of "knock":
    return (true, %*{
      "knock_room_state": roomStateArray(state.rooms[roomId])
    }, "", "")
  of "invite":
    return (true, %*{
      "event": appended.event.eventToJson()
    }, "", "")
  else:
    return (true, %*{}, "", "")

{.push warning[Uninit]: off.}
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
  let allowLocalPresence = getConfigBool(
    cfg.values,
    ["global.allow_local_presence", "allow_local_presence"],
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
  let loginTokenTtlMs = max(1, getConfigInt(cfg.values, ["login_token_ttl", "global.login_token_ttl"], 120000)).int64
  let refreshTokenTtlMs = max(1, getConfigInt(cfg.values, ["access_token_ttl", "global.access_token_ttl"], 604800)).int64 * 1000'i64

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

    let ssoLoginParts = ssoLoginPathParts(path)
    if ssoLoginParts.ok:
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      let providerOpt = ssoProviderFromConfig(cfg.values)
      if providerOpt.isNone:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "No SSO identity providers are configured."))
        return
      let provider = providerOpt.get()
      if not provider.providerMatches(ssoLoginParts.providerId):
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "SSO identity provider was not found."))
        return
      if getConfigBool(cfg.values, ["sso_custom_providers_page", "global.sso_custom_providers_page"], false) and
          ssoLoginParts.providerId.len == 0:
        await respondJson(req, Http501, matrixError("M_NOT_IMPLEMENTED", "Custom SSO providers page is enabled."))
        return
      let redirectUrl = queryParam(req, "redirectUrl")
      if redirectUrl.len == 0 or not (redirectUrl.startsWith("http://") or redirectUrl.startsWith("https://") or redirectUrl.startsWith("uiaa:")):
        await respondJson(req, Http400, matrixError("M_INVALID_PARAM", "Invalid redirectUrl."))
        return
      var session: SsoSessionRecord
      withLock state.lock:
        session = state.createSsoSessionLocked(provider, redirectUrl, queryParam(req, "loginToken"))
        state.savePersistentState()
      await respondRedirect(req, ssoAuthorizationLocation(provider, session), ssoCookie(session, provider))
      return

    let callbackProviderId = ssoCallbackProviderId(path)
    if callbackProviderId.len > 0:
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      let providerOpt = ssoProviderFromConfig(cfg.values)
      if providerOpt.isNone:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "No SSO identity providers are configured."))
        return
      let provider = providerOpt.get()
      if not provider.providerMatches(callbackProviderId):
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "SSO identity provider was not found."))
        return
      let callbackError = queryParam(req, "error")
      if callbackError.len > 0:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "SSO callback error: " & callbackError))
        return
      let sessionId = queryParam(req, "state")
      let code = queryParam(req, "code")
      if sessionId.len == 0:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Missing state in callback."))
        return
      if code.len == 0:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Missing code in callback."))
        return

      var sessionFound = false
      var sessionExpired = false
      var sessionMismatch = false
      var session: SsoSessionRecord
      withLock state.lock:
        if sessionId in state.ssoSessions:
          sessionFound = true
          session = state.ssoSessions[sessionId]
          sessionExpired = session.expiresAtMs <= nowMs()
          sessionMismatch = session.idpId != provider.id
          if sessionExpired:
            state.ssoSessions.del(sessionId)
            state.savePersistentState()
      if not sessionFound:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Invalid state in callback."))
        return
      if sessionMismatch:
        await respondJson(req, Http401, matrixError("M_UNAUTHORIZED", "Identity provider session was not recognized."))
        return
      if sessionExpired:
        await respondJson(req, Http401, matrixError("M_UNAUTHORIZED", "Authorization grant session has expired."))
        return

      var claims = newJObject()
      if session.userId.len == 0:
        let userInfo = await requestSsoUserInfo(provider, session, code)
        if not userInfo.ok:
          await respondJson(req, Http501, matrixError(userInfo.errcode, userInfo.message))
          return
        claims = userInfo.payload

      var complete: tuple[ok: bool, userId: string, errcode: string, message: string]
      var loginToken = ""
      withLock state.lock:
        complete = state.ensureSsoUserLocked(provider, session, claims)
        if complete.ok:
          loginToken = state.createLoginTokenLocked(complete.userId, loginTokenTtlMs).loginToken
          state.ssoSessions.del(sessionId)
          state.savePersistentState()
      if not complete.ok:
        await respondJson(req, Http403, matrixError(complete.errcode, complete.message))
        return
      let redirectTarget =
        if session.redirectUrl.startsWith("uiaa:"):
          "/_matrix/client/v3/auth/m.login.sso/fallback/web?session=" & encodeUrl(session.redirectUrl["uiaa:".len .. ^1])
        else:
          appendQueryParam(session.redirectUrl, "loginToken", loginToken)
      await respondRedirect(req, redirectTarget, "tuwunel_grant_session=; Max-Age=0; Path=/; HttpOnly")
      return

    if path == "/_matrix/client/v3/login" or path == "/_matrix/client/r0/login":
      if req.reqMethod == HttpGet:
        await respondJson(req, Http200, loginTypesResponseWithSso(cfg.values))
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
      let loginToken = body{"token"}.getStr("")
      let wantsRefreshToken = body{"refresh_token"}.getBool(false)
      var deviceId = body{"device_id"}.getStr("")
      if deviceId.len == 0:
        deviceId = randomString("DEV", 12)
      let deviceDisplayName = body{"initial_device_display_name"}.getStr("")

      var userId = ""
      var token = ""
      var refreshToken = ""
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
              token = state.addTokenForUser(userId, deviceId, deviceDisplayName)
              if wantsRefreshToken:
                refreshToken = state.createRefreshTokenLocked(userId, deviceId, refreshTokenTtlMs).refreshToken
              state.savePersistentState()
        elif loginType == "m.login.token":
          let consumed = state.consumeLoginTokenLocked(loginToken)
          if not consumed.ok:
            loginErrCode = consumed.errcode
            loginErrMsg = consumed.message
          else:
            userId = consumed.userId
            token = state.addTokenForUser(userId, deviceId, deviceDisplayName)
            if wantsRefreshToken:
              refreshToken = state.createRefreshTokenLocked(userId, deviceId, refreshTokenTtlMs).refreshToken
            state.savePersistentState()
        elif loginType == "m.login.application_service":
          let sessionRes = state.getSessionFromToken(accessToken, impersonateUser)
          if not sessionRes.ok:
            loginErrCode = sessionRes.errcode
            loginErrMsg = sessionRes.message
          else:
            userId = sessionRes.session.userId
            token = state.addTokenForUser(userId, deviceId, deviceDisplayName)
            if wantsRefreshToken:
              refreshToken = state.createRefreshTokenLocked(userId, deviceId, refreshTokenTtlMs).refreshToken
            state.savePersistentState()
        else:
          loginErrCode = "M_UNRECOGNIZED"
          loginErrMsg = "Unsupported login type."

      if loginErrCode.len > 0:
        let status = if loginErrCode == "M_FORBIDDEN": Http403 elif loginErrCode == "M_UNRECOGNIZED": Http400 else: Http401
        await respondJson(req, status, matrixError(loginErrCode, loginErrMsg))
        return

      var loginPayload = %*{
        "user_id": userId,
        "access_token": token,
        "device_id": deviceId,
        "home_server": serverName
      }
      if refreshToken.len > 0:
        loginPayload["refresh_token"] = %refreshToken
        loginPayload["expires_in_ms"] = %refreshTokenTtlMs
      await respondJson(req, Http200, loginPayload)
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
      let wantsRefreshToken = body{"refresh_token"}.getBool(false)
      var deviceId = body{"device_id"}.getStr("")
      if deviceId.len == 0:
        deviceId = randomString("DEV", 12)
      let deviceDisplayName = body{"initial_device_display_name"}.getStr("")

      var userId = ""
      var token = ""
      var refreshToken = ""
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
            avatarUrl: "",
            blurhash: "",
            timezone: "",
            profileFields: initTable[string, JsonNode]()
          )
          token = state.addTokenForUser(userId, deviceId, deviceDisplayName)
          if wantsRefreshToken:
            refreshToken = state.createRefreshTokenLocked(userId, deviceId, refreshTokenTtlMs).refreshToken
          state.savePersistentState()

      if registerErr:
        await respondJson(req, Http400, matrixError("M_USER_IN_USE", "User already exists."))
        return

      var registerPayload = %*{
        "user_id": userId,
        "access_token": token,
        "device_id": deviceId,
        "home_server": serverName
      }
      if refreshToken.len > 0:
        registerPayload["refresh_token"] = %refreshToken
        registerPayload["expires_in_ms"] = %refreshTokenTtlMs
      await respondJson(req, Http200, registerPayload)
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

    if isChangePasswordPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      let newPassword = parsed.value{"new_password"}.getStr("")
      if newPassword.len == 0:
        await respondJson(req, Http400, matrixError("M_MISSING_PARAM", "Missing new_password."))
        return
      let logoutDevices = parsed.value{"logout_devices"}.getBool(true)
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and resolved.session.userId in state.users:
          var user = state.users[resolved.session.userId]
          user.password = newPassword
          state.users[resolved.session.userId] = user
          if logoutDevices:
            var devicesToRemove = initHashSet[string]()
            for _, sess in state.tokens:
              if sess.userId == resolved.session.userId and sess.deviceId != resolved.session.deviceId:
                devicesToRemove.incl(sess.deviceId)
            for deviceId in devicesToRemove:
              state.removeTokensForDevice(resolved.session.userId, deviceId)
              state.devices.del(deviceKey(resolved.session.userId, deviceId))
          state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      await respondJson(req, Http200, %*{})
      return

    if isDeactivatePath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and resolved.session.userId in state.users:
          var roomsToLeave: seq[string] = @[]
          for roomId, room in state.rooms:
            let membership = room.members.getOrDefault(resolved.session.userId, "")
            if membership in ["join", "invite", "knock"]:
              roomsToLeave.add(roomId)
          for roomId in roomsToLeave:
            discard state.appendEventLocked(
              roomId,
              resolved.session.userId,
              "m.room.member",
              resolved.session.userId,
              membershipContent("leave"),
            )
          var user = state.users[resolved.session.userId]
          user.password = ""
          state.users[resolved.session.userId] = user
          var deviceKeysToDelete: seq[string] = @[]
          for key, device in state.devices:
            if device.userId == resolved.session.userId:
              deviceKeysToDelete.add(key)
          for key in deviceKeysToDelete:
            state.devices.del(key)
          state.removeAllTokensForUser(resolved.session.userId)
          state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      await respondJson(req, Http200, %*{"id_server_unbind_result": "no-support"})
      return

    let filterParts = userFilterPathParts(path)
    if filterParts.ok:
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not resolved.session.isAppservice and resolved.session.userId != filterParts.userId:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "You cannot access filters for other users."))
        return

      if filterParts.create:
        if req.reqMethod != HttpPost and req.reqMethod != HttpPut:
          await methodNotAllowed(req)
          return
        let parsed = parseRequestJson(req)
        if not parsed.ok or parsed.value.kind != JObject:
          await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
          return
        var filterId = ""
        withLock state.lock:
          for _ in 0 ..< 32:
            let candidate = randomString("", 4)
            if filterKey(filterParts.userId, candidate) notin state.filters:
              filterId = candidate
              break
          if filterId.len == 0:
            filterId = randomString("", 12)
          state.filters[filterKey(filterParts.userId, filterId)] = parsed.value
          state.savePersistentState()
        await respondJson(req, Http200, %*{"filter_id": filterId})
        return

      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var found = false
      var payload = newJObject()
      withLock state.lock:
        let key = filterKey(filterParts.userId, filterParts.filterId)
        if key in state.filters:
          found = true
          payload = state.filters[key]
      if not found:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Filter not found."))
        return
      await respondJson(req, Http200, payload)
      return

    let accountParts = userAccountDataPathParts(path)
    if accountParts.ok:
      if req.reqMethod != HttpGet and req.reqMethod != HttpPut and req.reqMethod != HttpDelete:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not resolved.session.isAppservice and resolved.session.userId != accountParts.userId:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "You cannot access account data for other users."))
        return

      if req.reqMethod == HttpGet:
        var found = false
        var payload = newJObject()
        withLock state.lock:
          let data = state.getAccountDataLocked(accountParts.roomId, accountParts.userId, accountParts.eventType)
          found = data.ok
          payload = data.content
        if not found:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Data not found."))
          return
        await respondJson(req, Http200, payload)
        return

      if accountParts.eventType == "m.fully_read":
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "This endpoint cannot be used for marking a room as fully read."))
        return
      if accountParts.eventType == "m.push_rules":
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "This endpoint cannot be used for setting push rules."))
        return

      let content =
        if req.reqMethod == HttpDelete:
          newJObject()
        else:
          block:
            let parsed = parseRequestJson(req)
            if not parsed.ok or parsed.value.kind != JObject:
              await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
              return
            parsed.value
      withLock state.lock:
        discard state.setAccountDataLocked(
          accountParts.roomId,
          accountParts.userId,
          accountParts.eventType,
          content
        )
        state.savePersistentState()
      await respondJson(req, Http200, %*{})
      return

    let tagsParts = userTagsPathParts(path)
    if tagsParts.ok:
      if tagsParts.collection:
        if req.reqMethod != HttpGet:
          await methodNotAllowed(req)
          return
      elif req.reqMethod != HttpPut and req.reqMethod != HttpDelete:
        await methodNotAllowed(req)
        return

      var tagContent = newJObject()
      if req.reqMethod == HttpPut:
        let parsed = parseRequestJson(req)
        if not parsed.ok or parsed.value.kind != JObject:
          await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
          return
        tagContent = parsed.value

      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var allowed = false
      var payload = %*{"tags": newJObject()}
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          allowed = resolved.session.isAppservice or resolved.session.userId == tagsParts.userId
          if allowed:
            allowed = state.roomJoinedForUser(tagsParts.roomId, tagsParts.userId)
          if allowed:
            if tagsParts.collection:
              payload = state.roomTagsContentLocked(tagsParts.roomId, tagsParts.userId)
            elif req.reqMethod == HttpPut:
              discard state.setRoomTagLocked(tagsParts.roomId, tagsParts.userId, tagsParts.tag, tagContent)
              state.savePersistentState()
            elif req.reqMethod == HttpDelete:
              discard state.deleteRoomTagLocked(tagsParts.roomId, tagsParts.userId, tagsParts.tag)
              state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not allowed:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "You cannot access tags for this room."))
        return
      await respondJson(req, Http200, if tagsParts.collection: payload else: %*{})
      return

    let typingParts = roomTypingPathParts(path)
    if typingParts.ok:
      if req.reqMethod != HttpPut:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var allowed = false
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          allowed = resolved.session.isAppservice or resolved.session.userId == typingParts.userId
          if allowed:
            allowed = state.roomJoinedForUser(typingParts.roomId, typingParts.userId)
            if allowed:
              let isTyping = parsed.value{"typing"}.getBool(false)
              let timeoutMs = parsed.value{"timeout"}.getInt(30000).int64
              state.setTypingLocked(typingParts.roomId, typingParts.userId, isTyping, timeoutMs)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not allowed:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "You are not joined to this room."))
        return
      await respondJson(req, Http200, %*{})
      return

    let receiptParts = roomReceiptPathParts(path)
    if receiptParts.ok:
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var threadId = queryParam(req, "thread_id")
      if threadId.len == 0 and parsed.value.hasKey("thread_id"):
        if parsed.value["thread_id"].kind != JString or parsed.value["thread_id"].getStr("").len == 0:
          await respondJson(req, Http400, matrixError("M_INVALID_PARAM", "thread_id must be a non-empty string."))
          return
        threadId = parsed.value["thread_id"].getStr("")
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var allowed = false
      var supportedReceipt = true
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          allowed = state.roomJoinedForUser(receiptParts.roomId, resolved.session.userId)
          if allowed:
            case receiptParts.receiptType
            of "m.fully_read":
              discard state.setAccountDataLocked(
                receiptParts.roomId,
                resolved.session.userId,
                "m.fully_read",
                %*{"event_id": receiptParts.eventId}
              )
              state.savePersistentState()
            of "m.read", "m.read.private":
              discard state.setReceiptLocked(
                receiptParts.roomId,
                receiptParts.eventId,
                receiptParts.receiptType,
                resolved.session.userId,
                threadId
              )
              state.savePersistentState()
            else:
              supportedReceipt = false
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not allowed:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "You are not joined to this room."))
        return
      if not supportedReceipt:
        await respondJson(req, Http400, matrixError("M_INVALID_PARAM", "Unsupported receipt type."))
        return
      await respondJson(req, Http200, %*{})
      return

    let readMarkerParts = roomReadMarkersPathParts(path)
    if readMarkerParts.ok:
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      let fullyReadEventId = firstJsonString(parsed.value, ["m.fully_read", "fully_read"])
      let publicReadEventId = firstJsonString(parsed.value, ["m.read", "read_receipt"])
      let privateReadEventId = firstJsonString(parsed.value, ["m.read.private", "private_read_receipt"])
      if fullyReadEventId.len == 0 and publicReadEventId.len == 0 and privateReadEventId.len == 0:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "No read marker or receipt event id supplied."))
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var allowed = false
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          allowed = state.roomJoinedForUser(readMarkerParts.roomId, resolved.session.userId)
          if allowed:
            if fullyReadEventId.len > 0:
              discard state.setAccountDataLocked(
                readMarkerParts.roomId,
                resolved.session.userId,
                "m.fully_read",
                %*{"event_id": fullyReadEventId}
              )
            if publicReadEventId.len > 0:
              discard state.setReceiptLocked(
                readMarkerParts.roomId,
                publicReadEventId,
                "m.read",
                resolved.session.userId,
                ""
              )
            if privateReadEventId.len > 0:
              discard state.setReceiptLocked(
                readMarkerParts.roomId,
                privateReadEventId,
                "m.read.private",
                resolved.session.userId,
                ""
              )
            state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not allowed:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "You are not joined to this room."))
        return
      await respondJson(req, Http200, %*{})
      return

    let deviceParts = devicePathParts(path)
    if deviceParts.ok:
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return

      if deviceParts.collection:
        if req.reqMethod != HttpGet:
          await methodNotAllowed(req)
          return
        var payload = newJObject()
        withLock state.lock:
          payload = state.listDevicesPayloadLocked(resolved.session.userId)
        await respondJson(req, Http200, payload)
        return

      if req.reqMethod == HttpGet:
        var found = false
        var payload = newJObject()
        withLock state.lock:
          let key = deviceKey(resolved.session.userId, deviceParts.deviceId)
          if key in state.devices:
            found = true
            payload = state.devices[key].deviceToJson()
        if not found:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Device not found."))
          return
        await respondJson(req, Http200, payload)
        return

      if req.reqMethod == HttpPut:
        let parsed = parseRequestJson(req)
        if not parsed.ok or parsed.value.kind != JObject:
          await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
          return
        var found = false
        withLock state.lock:
          let key = deviceKey(resolved.session.userId, deviceParts.deviceId)
          if key in state.devices:
            found = true
            var device = state.devices[key]
            if parsed.value.hasKey("display_name"):
              if parsed.value["display_name"].kind == JString:
                device.displayName = parsed.value["display_name"].getStr("")
              elif parsed.value["display_name"].kind == JNull:
                device.displayName = ""
            device.lastSeenTs = nowMs()
            state.devices[key] = device
            state.savePersistentState()
        if not found:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Device not found."))
          return
        await respondJson(req, Http200, %*{})
        return

      if req.reqMethod == HttpDelete:
        withLock state.lock:
          state.removeDeviceLocked(resolved.session.userId, deviceParts.deviceId)
          state.savePersistentState()
        await respondJson(req, Http200, %*{})
        return

      await methodNotAllowed(req)
      return

    if deleteDevicesPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if parsed.value{"devices"}.kind != JArray:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "devices must be an array."))
        return
      withLock state.lock:
        for deviceNode in parsed.value["devices"]:
          let deviceId = deviceNode.getStr("")
          if deviceId.len > 0:
            state.removeDeviceLocked(resolved.session.userId, deviceId)
        state.savePersistentState()
      await respondJson(req, Http200, %*{})
      return

    if path == "/_matrix/media/v3/config" or
        path == "/_matrix/media/v1/config" or
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

    if isMediaPreviewPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      let url = queryParam(req, "url").strip()
      if url.len == 0:
        await respondJson(req, Http400, matrixError("M_INVALID_PARAM", "Missing url query parameter."))
        return
      if not (url.startsWith("http://") or url.startsWith("https://")):
        await respondJson(req, Http400, matrixError("M_INVALID_PARAM", "Invalid preview URL."))
        return
      await respondJson(req, Http200, %*{
        "og:url": url,
        "og:title": url,
      })
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
      let media = loadStoredMedia(state, mediaDownload.mediaId)
      if not media.ok:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Media not found."))
        return
      await respondRaw(
        req,
        Http200,
        media.body,
        contentType = media.contentType,
        cacheControl = "public, max-age=31536000, immutable",
        contentDisposition = mediaContentDisposition(media.fileName)
      )
      return

    if isJoinedRoomsPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var payload = %*{"joined_rooms": []}
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          var rooms = newJArray()
          for roomId in state.joinedRoomsForUser(resolved.session.userId):
            rooms.add(%roomId)
          payload["joined_rooms"] = rooms
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      await respondJson(req, Http200, payload)
      return

    if isPublicRoomsPath(path):
      if req.reqMethod != HttpGet and req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed =
        if req.reqMethod == HttpPost:
          parseRequestJson(req)
        else:
          (ok: true, value: newJObject())
      if not parsed.ok or (req.reqMethod == HttpPost and parsed.value.kind != JObject):
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var payload = newJObject()
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          payload = publicRoomsPayload(state, parsed.value)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      await respondJson(req, Http200, payload)
      return

    if isThirdPartyProtocolsPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      await respondJson(req, Http200, %*{})
      return

    if isTurnServerPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      let turn = turnServerPayload(cfg.values, serverName, resolved.session.userId)
      if not turn.ok:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Not Found"))
        return
      await respondJson(req, Http200, turn.payload)
      return

    if isAccount3pidPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      await respondJson(req, Http200, accountThreepidsPayload())
      return

    if isNotificationsPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var payload = newJObject()
      var limit = 50
      let limitRaw = queryParam(req, "limit")
      if limitRaw.len > 0:
        try:
          limit = parseInt(limitRaw)
        except ValueError:
          await respondJson(req, Http400, matrixError("M_INVALID_PARAM", "Invalid `limit` parameter."))
          return
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          payload = state.notificationsPayload(
            resolved.session.userId,
            queryParam(req, "from"),
            queryParam(req, "only"),
            limit
          )
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      await respondJson(req, Http200, payload)
      return

    if isPushersPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      var payload: JsonNode
      withLock state.lock:
        payload = state.listPushersPayload(resolved.session.userId)
      await respondJson(req, Http200, payload)
      return

    if isPushersSetPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var setResult: tuple[ok: bool, errcode: string, message: string]
      withLock state.lock:
        setResult = state.setPusherLocked(resolved.session.userId, parsed.value)
        if setResult.ok:
          state.savePersistentState()
      if not setResult.ok:
        await respondJson(req, Http400, matrixError(setResult.errcode, setResult.message))
        return
      await respondJson(req, Http200, %*{})
      return

    if isPushRulesPath(path):
      if req.reqMethod notin {HttpGet, HttpPut, HttpDelete}:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      let rulePath = pushRulePathParts(path)
      if not rulePath.ok:
        await notFound(req)
        return
      if req.reqMethod == HttpGet:
        if rulePath.scope.len == 0:
          var payload: JsonNode
          withLock state.lock:
            payload = state.pushRulesPayload(resolved.session.userId)
          await respondJson(req, Http200, payload)
        elif rulePath.kind.len == 0:
          if rulePath.scope != "global":
            await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Push rule scope not found."))
          else:
            var payload: JsonNode
            withLock state.lock:
              payload = state.pushRuleScopePayload(resolved.session.userId, rulePath.scope)
            await respondJson(req, Http200, payload)
        elif rulePath.ruleId.len == 0:
          if rulePath.scope != "global" or not rulePath.kind.isPushRuleKind():
            await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Push rule kind not found."))
          else:
            var payload: JsonNode
            withLock state.lock:
              payload = state.pushRuleScopePayload(resolved.session.userId, rulePath.scope)[rulePath.kind]
            await respondJson(req, Http200, payload)
        else:
          var found: Option[JsonNode]
          withLock state.lock:
            found = state.getPushRuleLocked(resolved.session.userId, rulePath.scope, rulePath.kind, rulePath.ruleId)
          if found.isNone:
            await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Push rule not found."))
          elif rulePath.attr == "enabled":
            await respondJson(req, Http200, %*{"enabled": found.get{"enabled"}.getBool(true)})
          elif rulePath.attr == "actions":
            await respondJson(req, Http200, %*{"actions": found.get{"actions"}})
          elif rulePath.attr.len == 0:
            await respondJson(req, Http200, found.get)
          else:
            await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Push rule attribute not found."))
      else:
        if rulePath.scope != "global" or not rulePath.kind.isPushRuleKind() or rulePath.ruleId.len == 0:
          await respondJson(req, Http400, matrixError("M_INVALID_PARAM", "Invalid push rule path."))
          return
        if req.reqMethod == HttpDelete:
          withLock state.lock:
            state.pushRules.del(pushRuleKey(resolved.session.userId, rulePath.scope, rulePath.kind, rulePath.ruleId))
            state.savePersistentState()
          await respondJson(req, Http200, %*{})
          return
        let parsed = parseRequestJson(req)
        if not parsed.ok or parsed.value.kind != JObject:
          await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
          return
        var updateResult: tuple[ok: bool, errcode: string, message: string]
        withLock state.lock:
          if rulePath.attr.len == 0:
            updateResult = state.putPushRuleLocked(
              resolved.session.userId,
              rulePath.scope,
              rulePath.kind,
              rulePath.ruleId,
              parsed.value,
            )
          else:
            updateResult = state.updatePushRuleAttrLocked(
              resolved.session.userId,
              rulePath.scope,
              rulePath.kind,
              rulePath.ruleId,
              rulePath.attr,
              parsed.value,
            )
          if updateResult.ok:
            state.savePersistentState()
        if not updateResult.ok:
          await respondJson(req, Http400, matrixError(updateResult.errcode, updateResult.message))
          return
        await respondJson(req, Http200, %*{})
      return

    if isKeysUploadPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var uploadResult: tuple[ok: bool, errcode: string, message: string, payload: JsonNode]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          uploadResult = state.uploadE2eeKeysLocked(resolved.session.userId, resolved.session.deviceId, parsed.value)
          if uploadResult.ok:
            state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not uploadResult.ok:
        await respondJson(req, Http400, matrixError(uploadResult.errcode, uploadResult.message))
        return
      await respondJson(req, Http200, uploadResult.payload)
      return

    if isKeysQueryPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var payload = newJObject()
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          payload = keysQueryPayload(state, parsed.value)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      await respondJson(req, Http200, payload)
      return

    if isKeysClaimPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var payload = newJObject()
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          payload = state.claimE2eeKeysLocked(parsed.value)
          state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      await respondJson(req, Http200, payload)
      return

    if isKeysChangesPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var payload = newJObject()
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          payload = state.keyChangesPayloadLocked(queryParam(req, "from"), queryParam(req, "to"))
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      await respondJson(req, Http200, payload)
      return

    if isSigningKeyUploadPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var uploadResult: tuple[ok: bool, errcode: string, message: string]
      var payload = newJObject()
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          case signingKeyUploadKind(path)
          of "device_signing":
            uploadResult = state.uploadSigningKeysLocked(resolved.session.userId, parsed.value)
            payload = %*{}
          of "signatures":
            uploadResult = (true, "", "")
            payload = state.uploadKeySignaturesLocked(parsed.value)
          else:
            uploadResult = (false, "M_UNRECOGNIZED", "Unknown signing-key route.")
          if uploadResult.ok:
            state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not uploadResult.ok:
        await respondJson(req, Http400, matrixError(uploadResult.errcode, uploadResult.message))
        return
      await respondJson(req, Http200, payload)
      return

    if isSearchPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var payload = newJObject()
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          payload = state.searchRoomEventsPayload(
            resolved.session.userId,
            parsed.value,
            queryParam(req, "next_batch")
          )
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      await respondJson(req, Http200, payload)
      return

    if isUserDirectorySearchPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var payload = newJObject()
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          payload = userDirectorySearchPayload(state, parsed.value)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      await respondJson(req, Http200, payload)
      return

    let openIdParts = openIdPathParts(path)
    if openIdParts.ok:
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var forbidden = false
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and not resolved.session.isAppservice and resolved.session.userId != openIdParts.userId:
          forbidden = true
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if forbidden:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Cannot request OpenID token for another user."))
        return
      var payload = newJObject()
      withLock state.lock:
        payload = state.createOpenIdTokenPayload(openIdParts.userId, serverName)
        state.savePersistentState()
      await respondJson(req, Http200, payload)
      return

    let toDeviceParts = sendToDevicePathParts(path)
    if toDeviceParts.ok:
      if req.reqMethod != HttpPut:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var queueResult: tuple[ok: bool, errcode: string, message: string, queuedCount: int]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          queueResult = state.queueToDeviceMessagesLocked(
            resolved.session.userId,
            resolved.session.deviceId,
            toDeviceParts.eventType,
            toDeviceParts.txnId,
            parsed.value,
          )
          if queueResult.ok:
            state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not queueResult.ok:
        await respondJson(req, Http400, matrixError(queueResult.errcode, queueResult.message))
        return
      await respondJson(req, Http200, %*{})
      return

    let roomAliasParts = directoryAliasPathParts(path)
    if roomAliasParts.ok:
      if req.reqMethod notin {HttpGet, HttpPut, HttpDelete}:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var foundRoom = ""
      var sentEvent: MatrixEventRecord
      let parsed =
        if req.reqMethod == HttpPut:
          parseRequestJson(req)
        else:
          (ok: true, value: newJObject())
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          case req.reqMethod
          of HttpGet:
            foundRoom = state.findRoomByAliasLocked(roomAliasParts.alias)
          of HttpPut:
            let roomId = parsed.value{"room_id"}.getStr("")
            if roomId in state.rooms:
              let content = aliasContentWith(state.rooms[roomId], roomAliasParts.alias)
              sentEvent = state.appendEventLocked(roomId, resolved.session.userId, "m.room.canonical_alias", "", content)
              state.enqueueEventDeliveries(sentEvent)
              state.savePersistentState()
              foundRoom = roomId
          of HttpDelete:
            let roomId = state.findRoomByAliasLocked(roomAliasParts.alias)
            if roomId.len > 0:
              let content = aliasContentWithout(state.rooms[roomId], roomAliasParts.alias)
              sentEvent = state.appendEventLocked(roomId, resolved.session.userId, "m.room.canonical_alias", "", content)
              state.enqueueEventDeliveries(sentEvent)
              state.savePersistentState()
              foundRoom = roomId
          else:
            discard
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if foundRoom.len == 0:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room alias not found."))
        return
      if req.reqMethod == HttpGet:
        await respondJson(req, Http200, %*{"room_id": foundRoom, "servers": [serverName]})
      else:
        await respondJson(req, Http200, %*{})
      return

    let visibilityParts = roomVisibilityPathParts(path)
    if visibilityParts.ok:
      if req.reqMethod != HttpGet and req.reqMethod != HttpPut:
        await methodNotAllowed(req)
        return
      let parsed =
        if req.reqMethod == HttpPut:
          parseRequestJson(req)
        else:
          (ok: true, value: newJObject())
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var foundRoom = false
      var visibility = "private"
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and visibilityParts.roomId in state.rooms:
          foundRoom = true
          if req.reqMethod == HttpPut:
            visibility = parsed.value{"visibility"}.getStr("private")
            let joinRule = if visibility == "public": "public" else: "invite"
            let ev = state.appendEventLocked(
              visibilityParts.roomId,
              resolved.session.userId,
              "m.room.join_rules",
              "",
              %*{"join_rule": joinRule}
            )
            state.enqueueEventDeliveries(ev)
            state.savePersistentState()
          else:
            let key = stateKey("m.room.join_rules", "")
            if key in state.rooms[visibilityParts.roomId].stateByKey and
                state.rooms[visibilityParts.roomId].roomIsPublic():
              visibility = "public"
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not foundRoom:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      await respondJson(req, Http200, if req.reqMethod == HttpGet: %*{"visibility": visibility} else: %*{})
      return

    let reportParts = reportPathParts(path)
    if reportParts.ok:
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var reason = ""
      if parsed.value.hasKey("reason") and parsed.value["reason"].kind != JNull:
        if parsed.value["reason"].kind != JString:
          await respondJson(req, Http400, matrixError("M_BAD_JSON", "reason must be a string."))
          return
        reason = parsed.value["reason"].getStr("")
      if reason.len > ReportReasonMaxLen:
        await respondJson(
          req,
          Http400,
          matrixError("M_INVALID_PARAM", "Reason too long, should be 750 characters or fewer.")
        )
        return
      let score =
        if parsed.value.hasKey("score") and parsed.value["score"].kind == JInt:
          parsed.value["score"].getInt(0)
        else:
          0
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var foundRoom = false
      var eventExists = true
      var reporterInRoom = true
      var reportStored = false
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and reportParts.roomId in state.rooms:
          foundRoom = true
          if reportParts.eventId.len > 0:
            eventExists = roomEventIndex(state.rooms[reportParts.roomId], reportParts.eventId) >= 0
            reporterInRoom = state.roomJoinedForUser(reportParts.roomId, resolved.session.userId)
          if eventExists and reporterInRoom:
            discard state.appendReportLocked(
              resolved.session.userId,
              reportParts.roomId,
              reportParts.eventId,
              reason,
              score
            )
            reportStored = true
            state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not foundRoom:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      if not eventExists:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Event ID is not known to us or Event ID is invalid."))
        return
      if not reporterInRoom:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "You are not in the room you are reporting."))
        return
      if not reportStored:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Report target not found."))
        return
      await respondJson(req, Http200, %*{})
      return

    let forgetRoom = roomIdFromRoomsPath(path, "forget")
    if forgetRoom.len > 0:
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var forgetResult: tuple[ok: bool, changed: bool]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          forgetResult = state.forgetRoomLocked(resolved.session.userId, forgetRoom)
          if forgetResult.changed:
            state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not forgetResult.ok:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      await respondJson(req, Http200, %*{})
      return

    for actionName in ["kick", "ban", "unban"]:
      let actionRoom = roomIdFromRoomsPath(path, actionName)
      if actionRoom.len == 0:
        continue
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      let targetUser = parsed.value{"user_id"}.getStr("")
      if targetUser.len == 0:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "user_id is required."))
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var foundRoom = false
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and actionRoom in state.rooms:
          foundRoom = true
          let membership = if actionName == "ban": "ban" else: "leave"
          let actionResult = state.setRoomMembershipLocked(actionRoom, resolved.session.userId, targetUser, membership)
          if actionResult.ok:
            state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not foundRoom:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      await respondJson(req, Http200, %*{})
      return

    let knockTarget = knockTargetFromPath(path)
    if knockTarget.len > 0:
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var foundRoom = ""
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          foundRoom = state.resolveRoomByJoinTarget(knockTarget)
          if foundRoom.len > 0:
            let knockResult = state.setRoomMembershipLocked(foundRoom, resolved.session.userId, resolved.session.userId, "knock")
            if knockResult.ok:
              state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if foundRoom.len == 0:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      await respondJson(req, Http200, %*{"room_id": foundRoom})
      return

    let initialSyncRoom = roomInitialSyncId(path)
    if initialSyncRoom.len > 0:
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var limit = 10
      try:
        let raw = queryParam(req, "limit")
        if raw.len > 0:
          limit = parseInt(raw)
      except ValueError:
        discard
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var foundRoom = false
      var canView = false
      var payload = newJObject()
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and initialSyncRoom in state.rooms:
          foundRoom = true
          canView = state.roomVisibleToUser(initialSyncRoom, resolved.session.userId)
          if canView:
            payload = state.roomInitialSyncPayload(state.rooms[initialSyncRoom], resolved.session.userId, limit)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not foundRoom:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      if not canView:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "No room preview available."))
        return
      await respondJson(req, Http200, payload)
      return

    let summaryRoom = unstableSummaryRoomId(path)
    if summaryRoom.len > 0:
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var foundRoom = false
      var canView = false
      var payload = newJObject()
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and summaryRoom in state.rooms:
          foundRoom = true
          canView = state.roomVisibleToUser(summaryRoom, resolved.session.userId)
          if canView:
            payload = roomSummaryPayload(state.rooms[summaryRoom], resolved.session.userId)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not foundRoom:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      if not canView:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Room is not world readable or publicly accessible."))
        return
      await respondJson(req, Http200, payload)
      return

    let relationParts = relationPathParts(path)
    if relationParts.ok:
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var payloadResult: tuple[ok: bool, notFound: bool, payload: JsonNode]
      var limit = 30
      let limitRaw = queryParam(req, "limit")
      if limitRaw.len > 0:
        try:
          limit = max(1, min(100, parseInt(limitRaw)))
        except ValueError:
          discard
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          payloadResult = state.relatedEventsPayload(
            resolved.session.userId,
            relationParts,
            queryParam(req, "from"),
            queryParam(req, "to"),
            queryParam(req, "dir"),
            limit,
            queryParam(req, "recurse").toLowerAscii() in ["1", "true", "yes"],
          )
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not payloadResult.ok:
        if payloadResult.notFound:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Event not found in room."))
        else:
          await respondJson(req, Http403, matrixError("M_FORBIDDEN", "You cannot view this room."))
        return
      await respondJson(req, Http200, payloadResult.payload)
      return

    let threadsRoom = threadsRoomId(path)
    if threadsRoom.len > 0:
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var payloadResult: tuple[ok: bool, notFound: bool, payload: JsonNode]
      var limit = 10
      let limitRaw = queryParam(req, "limit")
      if limitRaw.len > 0:
        try:
          limit = max(1, min(100, parseInt(limitRaw)))
        except ValueError:
          discard
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          payloadResult = state.threadEventsPayload(
            resolved.session.userId,
            threadsRoom,
            queryParam(req, "from"),
            limit,
          )
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not payloadResult.ok:
        if payloadResult.notFound:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        else:
          await respondJson(req, Http403, matrixError("M_FORBIDDEN", "You cannot view this room."))
        return
      await respondJson(req, Http200, payloadResult.payload)
      return

    let hierarchyRoom = hierarchyRoomId(path)
    if hierarchyRoom.len > 0:
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var hierarchyResult: tuple[ok: bool, forbidden: bool, payload: JsonNode]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          hierarchyResult = state.roomHierarchyPayload(hierarchyRoom, resolved.session.userId)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not hierarchyResult.ok:
        if hierarchyResult.forbidden:
          await respondJson(req, Http403, matrixError("M_FORBIDDEN", "You cannot view this room hierarchy."))
        else:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      await respondJson(req, Http200, hierarchyResult.payload)
      return

    let mutualUser = mutualRoomsUserId(path)
    if mutualUser.len > 0:
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var payload = newJObject()
      var selfRequest = false
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          selfRequest = resolved.session.userId == mutualUser
          if not selfRequest:
            payload = state.mutualRoomsPayloadLocked(resolved.session.userId, mutualUser)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if selfRequest:
        await respondJson(req, Http400, matrixError("M_UNKNOWN", "You cannot request rooms in common with yourself."))
        return
      await respondJson(req, Http200, payload)
      return

    let upgradeRoom = upgradeRoomId(path)
    if upgradeRoom.len > 0:
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      let requestedVersion = parsed.value{"new_version"}.getStr("")
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var upgradeResult: tuple[ok: bool, forbidden: bool, replacementRoom: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          upgradeResult = state.upgradeRoomLocked(upgradeRoom, resolved.session.userId, requestedVersion)
          if upgradeResult.ok and not upgradeResult.forbidden:
            state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not upgradeResult.ok:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      if upgradeResult.forbidden:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "You are not in the room you are upgrading."))
        return
      await respondJson(req, Http200, %*{"replacement_room": upgradeResult.replacementRoom})
      return

    let roomKeysParts = roomKeysPathParts(path)
    if roomKeysParts.ok:
      if req.reqMethod notin {HttpGet, HttpPost, HttpPut, HttpDelete}:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return

      if roomKeysParts.kind == "version":
        if req.reqMethod == HttpPost:
          if roomKeysParts.version.len > 0:
            await methodNotAllowed(req)
            return
          let parsed = parseRequestJson(req)
          if not parsed.ok or parsed.value.kind != JObject:
            await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid backup metadata."))
            return
          var version = ""
          withLock state.lock:
            version = state.createBackupVersionLocked(resolved.session.userId, parsed.value).version
            state.savePersistentState()
          await respondJson(req, Http200, %*{"version": version})
        elif req.reqMethod == HttpGet:
          var found = false
          var payload = newJObject()
          withLock state.lock:
            var version = roomKeysParts.version
            if version.len == 0:
              version = state.latestBackupVersionLocked(resolved.session.userId)
            let key = backupVersionKey(resolved.session.userId, version)
            if version.len > 0 and key in state.backupVersions:
              found = true
              payload = state.backupVersionPayloadLocked(state.backupVersions[key])
          if not found:
            await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Key backup does not exist."))
            return
          await respondJson(req, Http200, payload)
        elif req.reqMethod == HttpPut:
          if roomKeysParts.version.len == 0:
            await respondJson(req, Http400, matrixError("M_MISSING_PARAM", "Backup version is required."))
            return
          let parsed = parseRequestJson(req)
          if not parsed.ok or parsed.value.kind != JObject:
            await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid backup metadata."))
            return
          var updated = false
          withLock state.lock:
            updated = state.updateBackupVersionLocked(resolved.session.userId, roomKeysParts.version, parsed.value)
            if updated:
              state.savePersistentState()
          if not updated:
            await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Tried to update nonexistent backup."))
            return
          await respondJson(req, Http200, %*{})
        elif req.reqMethod == HttpDelete:
          if roomKeysParts.version.len == 0:
            await respondJson(req, Http400, matrixError("M_MISSING_PARAM", "Backup version is required."))
            return
          withLock state.lock:
            state.deleteBackupVersionLocked(resolved.session.userId, roomKeysParts.version)
            state.savePersistentState()
          await respondJson(req, Http200, %*{})
        else:
          await methodNotAllowed(req)
        return

      let version = queryParam(req, "version")
      if version.len == 0:
        await respondJson(req, Http400, matrixError("M_MISSING_PARAM", "version query parameter is required."))
        return

      if req.reqMethod == HttpGet:
        var found = true
        var payload = newJObject()
        withLock state.lock:
          if roomKeysParts.roomId.len == 0:
            payload = state.backupRoomsPayloadLocked(resolved.session.userId, version)
          elif roomKeysParts.sessionId.len == 0:
            payload = state.backupRoomSessionsPayloadLocked(resolved.session.userId, version, roomKeysParts.roomId)
          else:
            let session = state.getBackupSessionLocked(
              resolved.session.userId,
              version,
              roomKeysParts.roomId,
              roomKeysParts.sessionId,
            )
            found = session.ok
            payload = session.payload
        if not found:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Backup key not found for this user's session."))
          return
        await respondJson(req, Http200, payload)
        return

      if req.reqMethod == HttpDelete:
        var exists = false
        var payload = newJObject()
        withLock state.lock:
          exists = state.backupVersionExistsLocked(resolved.session.userId, version)
          if exists:
            state.deleteBackupSessionsLocked(
              resolved.session.userId,
              version,
              roomKeysParts.roomId,
              roomKeysParts.sessionId,
            )
            payload = state.backupMutationPayloadLocked(resolved.session.userId, version)
            state.savePersistentState()
        if not exists:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Tried to update nonexistent backup."))
          return
        await respondJson(req, Http200, payload)
        return

      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid backup key payload."))
        return

      var latestVersion = ""
      var exists = false
      var mutationOk = true
      var mutationMessage = ""
      var payload = newJObject()
      withLock state.lock:
        latestVersion = state.latestBackupVersionLocked(resolved.session.userId)
        exists = state.backupVersionExistsLocked(resolved.session.userId, version)
        if exists and latestVersion.len > 0 and latestVersion != version:
          mutationOk = false
          mutationMessage = "You may only manipulate the most recently created version of the backup."
        elif exists:
          if roomKeysParts.roomId.len == 0:
            let rooms = parsed.value{"rooms"}
            if rooms.kind != JObject:
              mutationOk = false
              mutationMessage = "rooms must be an object."
            else:
              for roomId, roomNode in rooms:
                let sessions = roomNode{"sessions"}
                if sessions.kind != JObject:
                  continue
                for sessionId, sessionData in sessions:
                  let putResult = state.putBackupSessionLocked(
                    resolved.session.userId,
                    version,
                    roomId,
                    sessionId,
                    sessionData,
                    preferBest = false,
                  )
                  if not putResult.ok:
                    mutationOk = false
                    mutationMessage = putResult.message
                    break
                if not mutationOk:
                  break
          elif roomKeysParts.sessionId.len == 0:
            let sessions = parsed.value{"sessions"}
            if sessions.kind != JObject:
              mutationOk = false
              mutationMessage = "sessions must be an object."
            else:
              for sessionId, sessionData in sessions:
                let putResult = state.putBackupSessionLocked(
                  resolved.session.userId,
                  version,
                  roomKeysParts.roomId,
                  sessionId,
                  sessionData,
                  preferBest = false,
                )
                if not putResult.ok:
                  mutationOk = false
                  mutationMessage = putResult.message
                  break
          else:
            let putResult = state.putBackupSessionLocked(
              resolved.session.userId,
              version,
              roomKeysParts.roomId,
              roomKeysParts.sessionId,
              parsed.value,
              preferBest = true,
            )
            mutationOk = putResult.ok
            mutationMessage = putResult.message

          if mutationOk:
            payload = state.backupMutationPayloadLocked(resolved.session.userId, version)
            state.savePersistentState()
      if not exists:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Tried to update nonexistent backup."))
        return
      if not mutationOk:
        let code = if mutationMessage.startsWith("You may only"): Http400 else: Http400
        let errcode = if mutationMessage.startsWith("You may only"): "M_INVALID_PARAM" else: "M_BAD_JSON"
        await respondJson(req, code, matrixError(errcode, mutationMessage))
        return
      await respondJson(req, Http200, payload)
      return

    let dehydratedParts = dehydratedDevicePathParts(path)
    if dehydratedParts.ok:
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return

      if dehydratedParts.events:
        if req.reqMethod != HttpGet:
          await methodNotAllowed(req)
          return
        var found = false
        withLock state.lock:
          if resolved.session.userId in state.dehydratedDevices:
            found = state.dehydratedDevices[resolved.session.userId].deviceId == dehydratedParts.deviceId
        if not found:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "No dehydrated device is stored."))
          return
        await respondJson(req, Http200, %*{"events": [], "next_batch": ""})
      elif req.reqMethod == HttpGet:
        var found = false
        var payload = newJObject()
        withLock state.lock:
          if resolved.session.userId in state.dehydratedDevices:
            found = true
            payload = dehydratedDevicePayload(state.dehydratedDevices[resolved.session.userId])
        if not found:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "No dehydrated device is stored."))
          return
        await respondJson(req, Http200, payload)
      elif req.reqMethod == HttpPut:
        let parsed = parseRequestJson(req)
        if not parsed.ok or parsed.value.kind != JObject:
          await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid dehydrated device payload."))
          return
        var deviceId = ""
        withLock state.lock:
          deviceId = state.putDehydratedDeviceLocked(resolved.session.userId, parsed.value).deviceId
          state.savePersistentState()
        await respondJson(req, Http200, %*{"device_id": deviceId})
      elif req.reqMethod == HttpDelete:
        withLock state.lock:
          state.deleteDehydratedDeviceLocked(resolved.session.userId)
          state.savePersistentState()
        await respondJson(req, Http200, %*{})
      else:
        await methodNotAllowed(req)
      return

    if isEventsPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var streamResult: tuple[ok: bool, payload: JsonNode]
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          streamResult = state.eventStreamPayload(
            resolved.session.userId,
            queryParam(req, "room_id"),
            queryParam(req, "from"),
          )
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not streamResult.ok:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "No room preview available."))
        return
      await respondJson(req, Http200, streamResult.payload)
      return

    if isSyncV5Path(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var payload = newJObject()
      let sincePos = parseSlidingSyncPos(parsed.value{"pos"}.getStr(""))
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          payload = state.slidingSyncV5Payload(
            resolved.session.userId,
            resolved.session.deviceId,
            parsed.value,
            sincePos,
          )
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      await respondJson(req, Http200, payload)
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
      let setPresenceValue = queryParam(req, "set_presence").strip().toLowerAscii()
      if setPresenceValue.len > 0:
        if not isValidPresenceValue(setPresenceValue):
          await respondJson(req, Http400, matrixError("M_INVALID_PARAM", "Invalid presence value."))
          return
        if allowLocalPresence:
          withLock state.lock:
            discard state.setPresenceLocked(resolved.session.userId, setPresenceValue, "")
            state.savePersistentState()

      proc buildSyncPayload(): JsonNode =
        var joinObj = newJObject()
        var presenceEvents = newJArray()
        var toDeviceEvents = newJArray()
        var oneTimeKeyCounts = newJObject()
        var unusedFallbackKeyTypes = newJArray()
        var nextBatch = "s0"
        withLock state.lock:
          state.pruneExpiredTypingLocked()
          let toPos = state.streamPos
          let removedToDevice = state.removeToDeviceEventsLocked(
            resolved.session.userId,
            resolved.session.deviceId,
            sincePos,
          )
          toDeviceEvents = state.toDeviceEventsForSync(
            resolved.session.userId,
            resolved.session.deviceId,
            sincePos,
            toPos,
          )
          oneTimeKeyCounts = state.oneTimeKeyCountsLocked(resolved.session.userId, resolved.session.deviceId)
          unusedFallbackKeyTypes = state.unusedFallbackKeyTypesLocked(resolved.session.userId, resolved.session.deviceId)
          let joinedRooms = state.joinedRoomsForUser(resolved.session.userId)
          for roomId in joinedRooms:
            if roomId notin state.rooms:
              continue
            var timelineEvents = newJArray()
            var room = state.rooms[roomId]
            for ev in room.timeline:
              if ev.streamPos > sincePos:
                timelineEvents.add(ev.eventToJson())

            var stateEvents = newJArray()
            if fullState or sincePos == 0:
              discard state.ensureDefaultRoomStateLocked(roomId, resolved.session.userId)
              room = state.rooms[roomId]
              var allState: seq[MatrixEventRecord] = @[]
              for _, stateEv in room.stateByKey:
                allState.add(stateEv)
              allState.sort(proc(a, b: MatrixEventRecord): int = cmp(a.streamPos, b.streamPos))
              for stateEv in allState:
                stateEvents.add(stateEv.eventToJson())

            let initialSync = fullState or sincePos == 0
            let roomAccountDataEvents =
              state.accountDataEventsForSync(resolved.session.userId, roomId, sincePos, initialSync)
            var ephemeralEvents = state.typingEventsForSync(roomId, sincePos, initialSync)
            for receiptEvent in state.receiptEventsForSync(roomId, sincePos, initialSync):
              ephemeralEvents.add(receiptEvent)
            if timelineEvents.len > 0 or stateEvents.len > 0 or
                roomAccountDataEvents.len > 0 or ephemeralEvents.len > 0 or fullState:
              joinObj[roomId] = %*{
                "timeline": {
                  "events": timelineEvents,
                  "limited": false,
                  "prev_batch": encodeSinceToken(sincePos),
                },
                "state": {
                  "events": stateEvents
                },
                "account_data": {
                  "events": roomAccountDataEvents
                },
                "ephemeral": {
                  "events": ephemeralEvents
                },
                "unread_notifications": {
                  "highlight_count": 0,
                  "notification_count": 0
                }
              }
          if allowLocalPresence:
            presenceEvents = state.presenceEventsForSync(
              resolved.session.userId,
              sincePos,
              fullState or sincePos == 0
            )
          if removedToDevice:
            state.savePersistentState()
          nextBatch = encodeSinceToken(state.streamPos)

        %*{
          "next_batch": nextBatch,
          "rooms": {
            "join": joinObj,
            "invite": {},
            "leave": {},
          },
          "account_data": {
            "events": state.accountDataEventsForSync(resolved.session.userId, "", sincePos, fullState or sincePos == 0)
          },
          "presence": {
            "events": presenceEvents,
          },
          "to_device": {
            "events": toDeviceEvents,
          },
          "device_one_time_keys_count": oneTimeKeyCounts,
          "device_unused_fallback_key_types": unusedFallbackKeyTypes,
        }

      var payload = buildSyncPayload()
      if payload["rooms"]["join"].len == 0 and
          payload["account_data"]["events"].len == 0 and
          payload["presence"]["events"].len == 0 and
          payload["to_device"]["events"].len == 0 and
          timeoutMs > 0:
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
                  avatarUrl: "",
                  blurhash: "",
                  timezone: "",
                  profileFields: initTable[string, JsonNode]()
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
              avatarUrl: "",
              blurhash: "",
              timezone: "",
              profileFields: initTable[string, JsonNode]()
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
      let membership = queryParam(req, "membership")
      let notMembership = queryParam(req, "not_membership")
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var foundRoom = false
      var payload = %*{"chunk": newJArray()}
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and membersRoom in state.rooms:
          if resolved.session.isAppservice or state.roomJoinedForUser(membersRoom, resolved.session.userId):
            foundRoom = true
            payload = %*{"chunk": roomMembersArray(state.rooms[membersRoom], membership, notMembership)}
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not foundRoom:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      await respondJson(req, Http200, payload)
      return

    let aliasesRoom = roomIdFromRoomsPath(path, "aliases")
    if aliasesRoom.len > 0:
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var foundRoom = false
      var payload = %*{"aliases": newJArray()}
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and aliasesRoom in state.rooms:
          if resolved.session.isAppservice or state.roomJoinedForUser(aliasesRoom, resolved.session.userId):
            foundRoom = true
            payload = roomAliasesPayload(state.rooms[aliasesRoom])
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not foundRoom:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      await respondJson(req, Http200, payload)
      return

    let eventParts = roomAndEventFromPath(path, "event")
    if eventParts.roomId.len > 0:
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var roomOk = false
      var foundEvent = false
      var payload = newJObject()
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and eventParts.roomId in state.rooms:
          if resolved.session.isAppservice or state.roomJoinedForUser(eventParts.roomId, resolved.session.userId):
            roomOk = true
            let room = state.rooms[eventParts.roomId]
            let idx = roomEventIndex(room, eventParts.eventId)
            if idx >= 0:
              foundEvent = true
              payload = room.timeline[idx].eventToJson()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not roomOk:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      if not foundEvent:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Event not found."))
        return
      await respondJson(req, Http200, payload)
      return

    let contextParts = roomAndEventFromPath(path, "context")
    if contextParts.roomId.len > 0:
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var limit = 10
      let limitRaw = queryParam(req, "limit")
      if limitRaw.len > 0:
        try:
          limit = max(0, min(100, parseInt(limitRaw)))
        except ValueError:
          discard
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var roomOk = false
      var foundEvent = false
      var payload = newJObject()
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok and contextParts.roomId in state.rooms:
          if resolved.session.isAppservice or state.roomJoinedForUser(contextParts.roomId, resolved.session.userId):
            roomOk = true
            let room = state.rooms[contextParts.roomId]
            let idx = roomEventIndex(room, contextParts.eventId)
            if idx >= 0:
              foundEvent = true
              payload = roomContextPayload(room, idx, limit)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if not roomOk:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
        return
      if not foundEvent:
        await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Event not found."))
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
      var limit = 10
      let limitRaw = queryParam(req, "limit")
      if limitRaw.len > 0:
        try:
          limit = max(1, min(1000, parseInt(limitRaw)))
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
              let toPos = parseSinceToken(queryParam(req, "to"))
              for idx in countdown(room.timeline.high, 0):
                let ev = room.timeline[idx]
                if ev.streamPos >= fromPos:
                  continue
                if toPos > 0 and ev.streamPos <= toPos:
                  break
                chunk.add(ev.eventToJson())
                endPos = ev.streamPos
                if chunk.len >= limit:
                  break
              payload["chunk"] = chunk
              payload["start"] = %encodeSinceToken(fromPos)
              payload["end"] = %(if endPos > 0: encodeSinceToken(endPos) else: "")
            else:
              var endPos = 0'i64
              let toPos = parseSinceToken(queryParam(req, "to"))
              for ev in room.timeline:
                if ev.streamPos <= fromPos:
                  continue
                if toPos > 0 and ev.streamPos >= toPos:
                  break
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
                payload = stateEventResponsePayload(room.stateByKey[key], queryParam(req, "format"))
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

    let presenceParts = presencePathParts(path)
    if presenceParts.ok:
      if not allowLocalPresence:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Presence is disabled on this server."))
        return

      if req.reqMethod == HttpGet:
        var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
        var found = false
        var visible = false
        var payload = newJObject()
        withLock state.lock:
          resolved = state.getSessionFromToken(accessToken, impersonateUser)
          if resolved.ok:
            visible = resolved.session.isAppservice or
              state.usersShareJoinedRoom(resolved.session.userId, presenceParts.userId)
            if visible and presenceParts.userId in state.presence:
              found = true
              payload = presenceResponseJson(state.presence[presenceParts.userId])
        if not resolved.ok:
          await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
          return
        if not visible or not found:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Presence state for this user was not found."))
          return
        await respondJson(req, Http200, payload)
        return

      if req.reqMethod != HttpPut:
        await methodNotAllowed(req)
        return

      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      let presenceValue = parsed.value{"presence"}.getStr("").toLowerAscii()
      if not isValidPresenceValue(presenceValue):
        await respondJson(req, Http400, matrixError("M_INVALID_PARAM", "Invalid presence value."))
        return
      let statusMsg =
        if parsed.value.hasKey("status_msg") and parsed.value["status_msg"].kind == JString:
          parsed.value["status_msg"].getStr("")
        else:
          ""

      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var forbidden = false
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          if not resolved.session.isAppservice and resolved.session.userId != presenceParts.userId:
            forbidden = true
          else:
            discard state.setPresenceLocked(presenceParts.userId, presenceValue, statusMsg)
            state.savePersistentState()
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      if forbidden:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Not allowed to set presence of other users."))
        return
      await respondJson(req, Http200, %*{})
      return

    let profileParts = profilePathParts(path)
    if profileParts.userId.len > 0:
      if req.reqMethod == HttpGet:
        var found = false
        var payload = newJObject()
        withLock state.lock:
          if profileParts.userId in state.users:
            let user = state.users[profileParts.userId]
            let field = profileFieldPayload(user, profileParts.field)
            found = field.ok
            payload = field.payload
        if not found:
          await notFoundWithCode(req, "M_NOT_FOUND")
          return
        await respondJson(req, Http200, payload)
        return

      if req.reqMethod != HttpPut and req.reqMethod != HttpDelete:
        await methodNotAllowed(req)
        return
      let parsed =
        if req.reqMethod == HttpDelete:
          (ok: true, value: newJObject())
        else:
          parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
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
                avatarUrl: "",
                blurhash: "",
                timezone: "",
                profileFields: initTable[string, JsonNode]()
              )
              if local.len > 0 and local notin state.usersByName:
                state.usersByName[local] = profileParts.userId
            var user = state.users[profileParts.userId]
            if req.reqMethod == HttpDelete:
              user.deleteUserProfileField(profileParts.field)
            else:
              user.setUserProfileField(profileParts.field, parsed.value)
            state.users[profileParts.userId] = user
            discard state.setPresenceLocked(profileParts.userId, "online", "")
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

    let parsedAppservicePing = parseAppservicePingPath(path)
    if parsedAppservicePing.ok or looksLikeAppservicePingPath(path):
      let accessToken = queryAccessToken(req)
      let authPresent = accessToken.strip().len > 0
      if not parsedAppservicePing.ok:
        logRejectedAppservicePing(req.reqMethod, path, "", authPresent, "invalid_path")
        await notFound(req)
        return
      if req.reqMethod != HttpPost:
        logRejectedAppservicePing(
          req.reqMethod,
          parsedAppservicePing.normalizedPath,
          parsedAppservicePing.registrationId,
          authPresent,
          "method_not_allowed"
        )
        await methodNotAllowed(req)
        return
      let response = appservicePingResponseForRegs(
        state.appserviceRegs,
        parsedAppservicePing.registrationId,
        accessToken
      )
      if response.code != Http200:
        logRejectedAppservicePing(
          req.reqMethod,
          parsedAppservicePing.normalizedPath,
          parsedAppservicePing.registrationId,
          authPresent,
          response.rejectionReason
        )
      await respondJson(req, response.code, response.payload)
      return

    if path == "/_matrix/client/v3/login" or path == "/_matrix/client/r0/login":
      if req.reqMethod == HttpGet:
        await respondJson(req, Http200, loginTypesResponseWithSso(cfg.values))
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

    if isRegistrationTokenValidityPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      var registrationToken = getConfigString(
        cfg.values,
        ["registration_token", "global.registration_token"],
        "",
      ).strip()
      let registrationTokenFile = getConfigString(
        cfg.values,
        ["registration_token_file", "global.registration_token_file"],
        "",
      ).strip()
      if registrationToken.len == 0 and registrationTokenFile.len > 0 and fileExists(registrationTokenFile):
        try:
          registrationToken = readFile(registrationTokenFile).strip()
        except CatchableError:
          discard
      if registrationToken.len == 0:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Server does not allow token registration."))
        return
      await respondJson(req, Http200, %*{"valid": queryParam(req, "token") == registrationToken})
      return

    if isRequest3pidManagementTokenPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      await respondJson(req, Http403, matrixError("M_THREEPID_DENIED", "Third party identifiers are not implemented."))
      return

    if isLoginTokenPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      var resolved: tuple[ok: bool, session: AccessSession, errcode: string, message: string]
      var issued = LoginTokenRecord()
      withLock state.lock:
        resolved = state.getSessionFromToken(accessToken, impersonateUser)
        if resolved.ok:
          issued = state.createLoginTokenLocked(resolved.session.userId, loginTokenTtlMs)
      if not resolved.ok:
        await respondJson(req, Http401, matrixError(resolved.errcode, resolved.message))
        return
      await respondJson(req, Http200, %*{
        "login_token": issued.loginToken,
        "expires_in_ms": loginTokenTtlMs
      })
      return

    if isRefreshTokenPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      let parsed = parseRequestJson(req)
      if not parsed.ok or parsed.value.kind != JObject:
        await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
        return
      var refreshed: tuple[ok: bool, accessToken: string, refreshToken: string, expiresInMs: int64, errcode: string, message: string]
      withLock state.lock:
        refreshed = state.refreshAccessTokenLocked(
          parsed.value{"refresh_token"}.getStr(""),
          "",
          refreshTokenTtlMs,
        )
        if refreshed.ok:
          state.savePersistentState()
      if not refreshed.ok:
        await respondJson(req, Http403, matrixError(refreshed.errcode, refreshed.message))
        return
      await respondJson(req, Http200, %*{
        "access_token": refreshed.accessToken,
        "refresh_token": refreshed.refreshToken,
        "expires_in_ms": refreshed.expiresInMs
      })
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
      if not allowFederation:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Federation is disabled."))
        return
      var count = 0
      withLock state.lock:
        count = state.users.len
      await respondJson(req, Http200, %*{"count": count})
      return

    if path == "/.well-known/matrix/client":
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      let payloadResult = wellKnownClientPayload(cfg.values)
      if not payloadResult.ok:
        await notFoundWithCode(req, "M_NOT_FOUND")
        return
      await respondJson(req, Http200, payloadResult.payload)
      return

    if path == "/.well-known/matrix/support":
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      let payloadResult = wellKnownSupportPayload(cfg.values)
      if not payloadResult.ok:
        await notFoundWithCode(req, "M_NOT_FOUND")
        return
      await respondJson(req, Http200, payloadResult.payload)
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
        return
      let payloadResult = wellKnownServerPayload(cfg.values)
      if not payloadResult.ok:
        await notFoundWithCode(req, "M_NOT_FOUND")
      else:
        await respondJson(req, Http200, payloadResult.payload)
      return

    if path == "/_matrix/key/v2/server" or path.startsWith("/_matrix/key/v2/server/"):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      if not allowFederation:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Federation is disabled."))
        return
      await respondJson(req, Http200, serverKeysPayload(serverName))
      return

    if path.startsWith("/_matrix/federation/"):
      if not allowFederation:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Federation is disabled."))
        return

      let fedParts = federationPathParts(path)
      let federationNoAuth =
        (fedParts.len == 1 and fedParts[0] in ["version", "publicRooms"]) or
        (fedParts.len == 2 and fedParts[0] == "openid" and fedParts[1] == "userinfo")
      if not federationNoAuth and not fedAuth:
        await respondJson(req, Http401, matrixError("M_UNAUTHORIZED", "Missing federation authentication."))
        return

      if fedParts.len == 1 and fedParts[0] == "version":
        if req.reqMethod != HttpGet:
          await methodNotAllowed(req)
          return
        await respondJson(req, Http200, federationVersionPayload())
        return

      if fedParts.len == 1 and fedParts[0] == "publicRooms":
        if req.reqMethod != HttpGet and req.reqMethod != HttpPost:
          await methodNotAllowed(req)
          return
        let parsed =
          if req.reqMethod == HttpPost:
            parseRequestJson(req)
          else:
            (ok: true, value: newJObject())
        if not parsed.ok or (req.reqMethod == HttpPost and parsed.value.kind != JObject):
          await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
          return
        var payload = newJObject()
        withLock state.lock:
          payload = publicRoomsPayload(state, parsed.value)
        await respondJson(req, Http200, payload)
        return

      let federationMedia = federationMediaPathParts(path)
      if federationMedia.ok:
        if req.reqMethod != HttpGet:
          await methodNotAllowed(req)
          return
        let media = loadStoredMedia(state, federationMedia.mediaId)
        if not media.ok:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Media not found."))
          return
        await respondRaw(
          req,
          Http200,
          media.body,
          contentType = media.contentType,
          cacheControl = "public, max-age=31536000, immutable",
          contentDisposition = mediaContentDisposition(media.fileName)
        )
        return

      if fedParts.len == 2 and fedParts[0] == "openid" and fedParts[1] == "userinfo":
        if req.reqMethod != HttpGet:
          await methodNotAllowed(req)
          return
        var userInfo: tuple[ok: bool, payload: JsonNode]
        withLock state.lock:
          userInfo = state.federationOpenIdUserInfoPayload(queryParam(req, "access_token"))
        if not userInfo.ok:
          await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown OpenID token."))
          return
        await respondJson(req, Http200, userInfo.payload)
        return

      if fedParts.len == 2 and fedParts[0] == "query" and fedParts[1] == "directory":
        if req.reqMethod != HttpGet:
          await methodNotAllowed(req)
          return
        var payloadResult: tuple[ok: bool, payload: JsonNode]
        withLock state.lock:
          payloadResult = state.federationDirectoryPayload(queryParam(req, "room_alias"), serverName)
        if not payloadResult.ok:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room alias not found."))
          return
        await respondJson(req, Http200, payloadResult.payload)
        return

      if fedParts.len == 2 and fedParts[0] == "query" and fedParts[1] == "profile":
        if req.reqMethod != HttpGet:
          await methodNotAllowed(req)
          return
        var payloadResult: tuple[ok: bool, payload: JsonNode]
        withLock state.lock:
          payloadResult = state.federationProfilePayload(queryParam(req, "user_id"), queryParam(req, "field"))
        if not payloadResult.ok:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Profile was not found."))
          return
        await respondJson(req, Http200, payloadResult.payload)
        return

      if fedParts.len == 2 and fedParts[0] == "event":
        if req.reqMethod != HttpGet:
          await methodNotAllowed(req)
          return
        var eventResult: tuple[ok: bool, payload: JsonNode]
        withLock state.lock:
          eventResult = state.federationEventPayload(fedParts[1])
        if not eventResult.ok:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Event not found."))
          return
        await respondJson(req, Http200, eventResult.payload)
        return

      if fedParts.len == 2 and fedParts[0] == "backfill":
        if req.reqMethod != HttpGet:
          await methodNotAllowed(req)
          return
        var limit = 50
        let rawLimit = queryParam(req, "limit")
        if rawLimit.len > 0:
          try:
            limit = parseInt(rawLimit)
          except ValueError:
            await respondJson(req, Http400, matrixError("M_INVALID_PARAM", "Invalid `limit` parameter."))
            return
        var backfillResult: tuple[ok: bool, payload: JsonNode]
        withLock state.lock:
          backfillResult = state.federationBackfillPayload(fedParts[1], queryParamValues(req, "v"), limit)
        if not backfillResult.ok:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
          return
        await respondJson(req, Http200, backfillResult.payload)
        return

      if fedParts.len == 2 and fedParts[0] == "get_missing_events":
        if req.reqMethod != HttpPost:
          await methodNotAllowed(req)
          return
        let parsed = parseRequestJson(req)
        if not parsed.ok or parsed.value.kind != JObject:
          await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
          return
        var missingResult: tuple[ok: bool, payload: JsonNode]
        withLock state.lock:
          missingResult = state.federationMissingEventsPayload(fedParts[1], parsed.value)
        if not missingResult.ok:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
          return
        await respondJson(req, Http200, missingResult.payload)
        return

      if fedParts.len == 2 and fedParts[0] == "send":
        if req.reqMethod != HttpPut:
          await methodNotAllowed(req)
          return
        let parsed = parseRequestJson(req)
        if not parsed.ok or parsed.value.kind != JObject:
          await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
          return
        if parsed.value{"origin"}.getStr(federationAuthOrigin(req)) != federationAuthOrigin(req):
          await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Not allowed to send transactions on behalf of other servers."))
          return
        var payload = newJObject()
        withLock state.lock:
          payload = state.federationSendTransactionLocked(federationAuthOrigin(req), fedParts[1], parsed.value)
          state.savePersistentState()
        await respondJson(req, Http200, payload)
        return

      if fedParts.len == 3 and fedParts[0] in ["make_join", "make_leave", "make_knock"]:
        if req.reqMethod != HttpGet:
          await methodNotAllowed(req)
          return
        let membership =
          case fedParts[0]
          of "make_join": "join"
          of "make_leave": "leave"
          else: "knock"
        var templateResult: tuple[ok: bool, payload: JsonNode]
        withLock state.lock:
          templateResult = state.membershipTemplateEvent(
            fedParts[1],
            fedParts[2],
            membership,
            federationAuthOrigin(req),
          )
        if not templateResult.ok:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room is unknown to this server."))
          return
        await respondJson(req, Http200, templateResult.payload)
        return

      if fedParts.len == 3 and fedParts[0] in ["send_join", "send_leave", "send_knock", "invite"]:
        if req.reqMethod != HttpPut:
          await methodNotAllowed(req)
          return
        let parsed = parseRequestJson(req)
        if not parsed.ok or parsed.value.kind != JObject:
          await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
          return
        let membership =
          case fedParts[0]
          of "send_join": "join"
          of "send_leave": "leave"
          of "send_knock": "knock"
          else: "invite"
        var acceptResult: tuple[ok: bool, payload: JsonNode, errcode: string, message: string]
        withLock state.lock:
          acceptResult = state.federationAcceptMembershipLocked(fedParts[1], fedParts[2], membership, parsed.value)
          if acceptResult.ok:
            state.savePersistentState()
        if not acceptResult.ok:
          let status = if acceptResult.errcode == "M_NOT_FOUND": Http404 else: Http400
          await respondJson(req, status, matrixError(acceptResult.errcode, acceptResult.message))
          return
        await respondJson(req, Http200, acceptResult.payload)
        return

      if fedParts.len == 3 and fedParts[0] == "event_auth":
        if req.reqMethod != HttpGet:
          await methodNotAllowed(req)
          return
        var authResult: tuple[ok: bool, eventKnown: bool, payload: JsonNode]
        withLock state.lock:
          authResult = state.federationEventAuthPayload(fedParts[1], fedParts[2])
        if not authResult.ok:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
          return
        if not authResult.eventKnown:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Event not found."))
          return
        await respondJson(req, Http200, authResult.payload)
        return

      if fedParts.len == 2 and fedParts[0] in ["state", "state_ids"]:
        if req.reqMethod != HttpGet:
          await methodNotAllowed(req)
          return
        var stateResult: tuple[ok: bool, eventKnown: bool, payload: JsonNode]
        withLock state.lock:
          stateResult = state.federationRoomStatePayload(
            fedParts[1],
            queryParam(req, "event_id"),
            fedParts[0] == "state_ids",
          )
        if not stateResult.ok:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
          return
        if not stateResult.eventKnown:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "PDU state not found."))
          return
        await respondJson(req, Http200, stateResult.payload)
        return

      if fedParts.len == 3 and fedParts[0] == "user" and fedParts[1] == "devices":
        if req.reqMethod != HttpGet:
          await methodNotAllowed(req)
          return
        var devicesResult: tuple[ok: bool, payload: JsonNode]
        withLock state.lock:
          devicesResult = state.federationUserDevicesPayload(fedParts[2])
        if not devicesResult.ok:
          await respondJson(req, Http404, matrixError("M_NOT_FOUND", "User not found."))
          return
        await respondJson(req, Http200, devicesResult.payload)
        return

      if fedParts.len == 3 and fedParts[0] == "user" and fedParts[1] == "keys" and
          fedParts[2] in ["query", "claim"]:
        if req.reqMethod != HttpPost:
          await methodNotAllowed(req)
          return
        let parsed = parseRequestJson(req)
        if not parsed.ok or parsed.value.kind != JObject:
          await respondJson(req, Http400, matrixError("M_BAD_JSON", "Invalid JSON body."))
          return
        var payload = newJObject()
        withLock state.lock:
          if fedParts[2] == "query":
            payload = keysQueryPayload(state, parsed.value)
            payload.delete("failures")
            payload.delete("user_signing_keys")
          else:
            payload = state.claimE2eeKeysLocked(parsed.value)
            state.savePersistentState()
        await respondJson(req, Http200, payload)
        return

      if fedParts.len == 2 and fedParts[0] == "hierarchy":
        if req.reqMethod != HttpGet:
          await methodNotAllowed(req)
          return
        var hierarchyResult: tuple[ok: bool, forbidden: bool, payload: JsonNode]
        withLock state.lock:
          hierarchyResult = state.roomHierarchyPayload(fedParts[1], "")
        if not hierarchyResult.ok:
          if hierarchyResult.forbidden:
            await respondJson(req, Http403, matrixError("M_FORBIDDEN", "You cannot view this room hierarchy."))
          else:
            await respondJson(req, Http404, matrixError("M_NOT_FOUND", "Room not found."))
          return
        await respondJson(req, Http200, hierarchyResult.payload)
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
{.pop.}

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

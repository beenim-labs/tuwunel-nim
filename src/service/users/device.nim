const
  RustPath* = "service/users/device.rs"
  RustCrate* = "service"
  DeviceIdLength* = 10
  TokenLength* = 32

import std/[algorithm, json, options, strutils, tables]

type
  UserResult* = tuple[ok: bool, errcode: string, message: string]
  DeviceCreateResult* = tuple[ok: bool, deviceId: string, errcode: string, message: string]
  TokenLookupResult* = tuple[ok: bool, userId: string, deviceId: string, expiresAtMs: Option[uint64]]
  StringFetchResult* = tuple[ok: bool, value: string, errcode: string, message: string]

  UserRecord* = object
    userId*: string
    username*: string
    password*: string
    origin*: string
    isGuest*: bool
    isAppservice*: bool
    displayName*: string
    avatarUrl*: string
    blurhash*: string
    timezone*: string
    profileFields*: Table[string, JsonNode]

  DeviceRecord* = object
    userId*: string
    deviceId*: string
    displayName*: string
    lastSeenIp*: string
    lastSeenTs*: uint64

  AccessTokenRecord* = object
    userId*: string
    deviceId*: string
    expiresAtMs*: Option[uint64]
    refreshToken*: string

  RefreshTokenRecord* = object
    userId*: string
    deviceId*: string

  ToDeviceEventRecord* = object
    streamPos*: uint64
    sender*: string
    targetUserId*: string
    targetDeviceId*: string
    eventType*: string
    content*: JsonNode

  DehydratedDeviceRecord* = object
    userId*: string
    deviceId*: string
    deviceData*: JsonNode

  OneTimeKeyRecord* = object
    userId*: string
    deviceId*: string
    keyId*: string
    key*: JsonNode

  FallbackKeyRecord* = object
    userId*: string
    deviceId*: string
    algorithm*: string
    keyId*: string
    key*: JsonNode
    used*: bool

  DeviceKeyRecord* = object
    userId*: string
    deviceId*: string
    keys*: JsonNode
    streamPos*: uint64

  CrossSigningKeyRecord* = object
    userId*: string
    keyType*: string
    key*: JsonNode

  DeviceListUpdateRecord* = object
    userId*: string
    streamPos*: uint64

  UserService* = object
    users*: Table[string, UserRecord]
    devices*: Table[string, DeviceRecord]
    accessTokens*: Table[string, AccessTokenRecord]
    refreshTokens*: Table[string, RefreshTokenRecord]
    userDeviceAccess*: Table[string, string]
    userDeviceRefresh*: Table[string, string]
    toDeviceEvents*: seq[ToDeviceEventRecord]
    oidcDevices*: Table[string, string]
    crossSigningReplacementUntil*: Table[string, uint64]
    devicelistVersions*: Table[string, uint64]
    dehydratedDevices*: Table[string, DehydratedDeviceRecord]
    oneTimeKeys*: Table[string, OneTimeKeyRecord]
    fallbackKeys*: Table[string, FallbackKeyRecord]
    lastOneTimeKeyUpdate*: Table[string, uint64]
    deviceKeys*: Table[string, DeviceKeyRecord]
    crossSigningKeys*: Table[string, CrossSigningKeyRecord]
    deviceListUpdates*: Table[string, DeviceListUpdateRecord]
    nextCount*: uint64

proc initUserService*(): UserService =
  UserService(
    users: initTable[string, UserRecord](),
    devices: initTable[string, DeviceRecord](),
    accessTokens: initTable[string, AccessTokenRecord](),
    refreshTokens: initTable[string, RefreshTokenRecord](),
    userDeviceAccess: initTable[string, string](),
    userDeviceRefresh: initTable[string, string](),
    toDeviceEvents: @[],
    oidcDevices: initTable[string, string](),
    crossSigningReplacementUntil: initTable[string, uint64](),
    devicelistVersions: initTable[string, uint64](),
    dehydratedDevices: initTable[string, DehydratedDeviceRecord](),
    oneTimeKeys: initTable[string, OneTimeKeyRecord](),
    fallbackKeys: initTable[string, FallbackKeyRecord](),
    lastOneTimeKeyUpdate: initTable[string, uint64](),
    deviceKeys: initTable[string, DeviceKeyRecord](),
    crossSigningKeys: initTable[string, CrossSigningKeyRecord](),
    deviceListUpdates: initTable[string, DeviceListUpdateRecord](),
    nextCount: 0'u64,
  )

proc okResult*(): UserResult =
  (true, "", "")

proc userError*(errcode, message: string): UserResult =
  (false, errcode, message)

proc nextStreamPos*(service: var UserService): uint64 =
  inc service.nextCount
  service.nextCount

proc userDeviceKey*(userId, deviceId: string): string =
  userId & "\0" & deviceId

proc localpart*(userId: string): string =
  if userId.len > 0 and userId[0] == '@':
    let colon = userId.find(':')
    if colon > 1:
      return userId[1 ..< colon]
  userId

proc createUserRecord*(
  userId: string;
  username = "";
  password = "";
  origin = "";
  isGuest = false;
  isAppservice = false;
): UserRecord =
  UserRecord(
    userId: userId,
    username: if username.len > 0: username else: localpart(userId),
    password: password,
    origin: origin,
    isGuest: isGuest,
    isAppservice: isAppservice,
    displayName: "",
    avatarUrl: "",
    blurhash: "",
    timezone: "",
    profileFields: initTable[string, JsonNode](),
  )

proc createUser*(
  service: var UserService;
  userId: string;
  username = "";
  password = "";
  origin = "";
  isGuest = false;
  isAppservice = false;
): UserResult =
  if userId.len == 0:
    return userError("M_INVALID_PARAM", "User ID is required.")
  if userId in service.users:
    return userError("M_USER_IN_USE", "User ID is not available.")
  service.users[userId] = createUserRecord(userId, username, password, origin, isGuest, isAppservice)
  okResult()

proc exists*(service: UserService; userId: string): bool =
  userId in service.users

proc generatedDeviceId(service: UserService): string =
  let n = $(service.devices.len + 1)
  "NIM" & repeat("0", max(0, DeviceIdLength - 3 - n.len)) & n

proc randomTokenLike(prefix: string; counter: uint64): string =
  let body = prefix & $counter
  if body.len >= TokenLength:
    body
  else:
    body & repeat("x", TokenLength - body.len)

proc bumpDeviceList*(service: var UserService; userId: string): uint64 =
  let version = service.devicelistVersions.getOrDefault(userId, 0'u64) + 1'u64
  service.devicelistVersions[userId] = version
  let pos = service.nextStreamPos()
  service.deviceListUpdates[userId] = DeviceListUpdateRecord(userId: userId, streamPos: pos)
  version

proc putDeviceMetadata*(
  service: var UserService;
  userId: string;
  device: DeviceRecord;
  notify = true;
) =
  service.devices[userDeviceKey(userId, device.deviceId)] = device
  if notify:
    discard service.bumpDeviceList(userId)

proc setRefreshToken*(service: var UserService; userId, deviceId, refreshToken: string): UserResult =
  if refreshToken.len == 0:
    return userError("M_INVALID_PARAM", "Refresh token is required.")
  let key = userDeviceKey(userId, deviceId)
  if key in service.userDeviceRefresh:
    service.refreshTokens.del(service.userDeviceRefresh[key])
  service.refreshTokens[refreshToken] = RefreshTokenRecord(userId: userId, deviceId: deviceId)
  service.userDeviceRefresh[key] = refreshToken
  okResult()

proc removeRefreshToken*(service: var UserService; userId, deviceId: string): UserResult =
  let key = userDeviceKey(userId, deviceId)
  if key notin service.userDeviceRefresh:
    return userError("M_NOT_FOUND", "Refresh token not found.")
  service.refreshTokens.del(service.userDeviceRefresh[key])
  service.userDeviceRefresh.del(key)
  okResult()

proc getRefreshToken*(service: UserService; userId, deviceId: string): StringFetchResult =
  let key = userDeviceKey(userId, deviceId)
  if key notin service.userDeviceRefresh:
    return (false, "", "M_NOT_FOUND", "Refresh token not found.")
  (true, service.userDeviceRefresh[key], "", "")

proc setAccessToken*(
  service: var UserService;
  userId, deviceId, accessToken: string;
  expiresAtMs: Option[uint64] = none(uint64);
  refreshToken = "";
): UserResult =
  if accessToken.len < TokenLength:
    return userError("M_INVALID_PARAM", "Access token is too short.")
  if refreshToken.len > 0:
    let refresh = service.setRefreshToken(userId, deviceId, refreshToken)
    if not refresh.ok:
      return refresh

  let key = userDeviceKey(userId, deviceId)
  if key in service.userDeviceAccess:
    service.accessTokens.del(service.userDeviceAccess[key])
  service.accessTokens[accessToken] = AccessTokenRecord(
    userId: userId,
    deviceId: deviceId,
    expiresAtMs: expiresAtMs,
    refreshToken: refreshToken,
  )
  service.userDeviceAccess[key] = accessToken
  okResult()

proc removeAccessToken*(service: var UserService; userId, deviceId: string): UserResult =
  let key = userDeviceKey(userId, deviceId)
  if key notin service.userDeviceAccess:
    return userError("M_NOT_FOUND", "Access token not found.")
  service.accessTokens.del(service.userDeviceAccess[key])
  service.userDeviceAccess.del(key)
  okResult()

proc getAccessToken*(service: UserService; userId, deviceId: string): StringFetchResult =
  let key = userDeviceKey(userId, deviceId)
  if key notin service.userDeviceAccess:
    return (false, "", "M_NOT_FOUND", "Access token not found.")
  (true, service.userDeviceAccess[key], "", "")

proc removeTokens*(service: var UserService; userId, deviceId: string) =
  discard service.removeAccessToken(userId, deviceId)
  discard service.removeRefreshToken(userId, deviceId)

proc findFromToken*(service: UserService; token: string): TokenLookupResult =
  if token in service.accessTokens:
    let record = service.accessTokens[token]
    return (true, record.userId, record.deviceId, record.expiresAtMs)
  if token in service.refreshTokens:
    let record = service.refreshTokens[token]
    return (true, record.userId, record.deviceId, none(uint64))
  (false, "", "", none(uint64))

proc generateAccessToken*(service: var UserService; expires = false; ttlMs = 0'u64): tuple[token: string, expiresAtMs: Option[uint64]] =
  result = ("", none(uint64))
  let pos = service.nextStreamPos()
  result.token = randomTokenLike("access_", pos)
  result.expiresAtMs = if expires: some(ttlMs) else: none(uint64)

proc generateRefreshToken*(service: var UserService): string =
  let pos = service.nextStreamPos()
  result = "refresh_" & randomTokenLike("", pos)

proc createDevice*(
  service: var UserService;
  userId: string;
  deviceId = "";
  accessToken = "";
  expiresAtMs: Option[uint64] = none(uint64);
  refreshToken = "";
  initialDeviceDisplayName = "";
  clientIp = "";
  nowMs = 0'u64;
): DeviceCreateResult =
  if not service.exists(userId):
    return (false, "", "M_INVALID_PARAM", "Called createDevice for non-existent user.")

  let actualDeviceId = if deviceId.len > 0: deviceId else: service.generatedDeviceId()
  service.putDeviceMetadata(
    userId,
    DeviceRecord(
      userId: userId,
      deviceId: actualDeviceId,
      displayName: initialDeviceDisplayName,
      lastSeenIp: clientIp,
      lastSeenTs: nowMs,
    ),
    notify = true,
  )

  if accessToken.len > 0:
    let tokenResult = service.setAccessToken(userId, actualDeviceId, accessToken, expiresAtMs, refreshToken)
    if not tokenResult.ok:
      return (false, "", tokenResult.errcode, tokenResult.message)

  (true, actualDeviceId, "", "")

proc removeDevice*(service: var UserService; userId, deviceId: string) =
  service.removeTokens(userId, deviceId)
  service.devices.del(userDeviceKey(userId, deviceId))
  service.oidcDevices.del(userDeviceKey(userId, deviceId))
  service.dehydratedDevices.del(userId)
  var retained: seq[ToDeviceEventRecord] = @[]
  for event in service.toDeviceEvents:
    if event.targetUserId != userId or event.targetDeviceId != deviceId:
      retained.add(event)
  service.toDeviceEvents = retained

  var oneTimeDelete: seq[string] = @[]
  for key, record in service.oneTimeKeys:
    if record.userId == userId and record.deviceId == deviceId:
      oneTimeDelete.add(key)
  for key in oneTimeDelete:
    service.oneTimeKeys.del(key)

  var fallbackDelete: seq[string] = @[]
  for key, record in service.fallbackKeys:
    if record.userId == userId and record.deviceId == deviceId:
      fallbackDelete.add(key)
  for key in fallbackDelete:
    service.fallbackKeys.del(key)

  discard service.bumpDeviceList(userId)

proc allDeviceIds*(service: UserService; userId: string): seq[string] =
  result = @[]
  for device in service.devices.values:
    if device.userId == userId:
      result.add(device.deviceId)
  result.sort(system.cmp[string])

proc getDeviceMetadata*(service: UserService; userId, deviceId: string): tuple[ok: bool, device: DeviceRecord] =
  let key = userDeviceKey(userId, deviceId)
  if key notin service.devices:
    return (false, DeviceRecord())
  (true, service.devices[key])

proc deviceExists*(service: UserService; userId, deviceId: string): bool =
  userDeviceKey(userId, deviceId) in service.devices

proc updateDeviceLastSeen*(
  service: var UserService;
  userId, deviceId: string;
  lastSeenIp = "";
  lastSeenTs = 0'u64;
): UserResult =
  let key = userDeviceKey(userId, deviceId)
  if key notin service.devices:
    return userError("M_NOT_FOUND", "Device not found.")
  var device = service.devices[key]
  if lastSeenIp.len > 0:
    device.lastSeenIp = lastSeenIp
  if lastSeenTs > 0:
    device.lastSeenTs = lastSeenTs
  service.putDeviceMetadata(userId, device, notify = false)
  okResult()

proc addToDeviceEvent*(
  service: var UserService;
  sender, targetUserId, targetDeviceId, eventType: string;
  content: JsonNode;
): uint64 =
  let pos = service.nextStreamPos()
  service.toDeviceEvents.add(ToDeviceEventRecord(
    streamPos: pos,
    sender: sender,
    targetUserId: targetUserId,
    targetDeviceId: targetDeviceId,
    eventType: eventType,
    content: if content.isNil: newJObject() else: content.copy(),
  ))
  pos

proc getToDeviceEvents*(
  service: UserService;
  userId, deviceId: string;
  since: Option[uint64] = none(uint64);
  toPos: Option[uint64] = none(uint64);
): seq[ToDeviceEventRecord] =
  result = @[]
  let lower = if since.isSome: since.get() else: 0'u64
  for event in service.toDeviceEvents:
    if event.targetUserId == userId and event.targetDeviceId == deviceId and
        event.streamPos > lower and (toPos.isNone or event.streamPos <= toPos.get()):
      result.add(event)
  result.sort(proc(a, b: ToDeviceEventRecord): int = cmp(a.streamPos, b.streamPos))

proc removeToDeviceEvents*(
  service: var UserService;
  userId, deviceId: string;
  until: Option[uint64] = none(uint64);
) =
  let upper = if until.isSome: until.get() else: high(uint64)
  var retained: seq[ToDeviceEventRecord] = @[]
  for event in service.toDeviceEvents:
    if event.targetUserId == userId and event.targetDeviceId == deviceId and event.streamPos <= upper:
      continue
    retained.add(event)
  service.toDeviceEvents = retained

proc markOidcDevice*(service: var UserService; userId, deviceId, idpId: string) =
  service.oidcDevices[userDeviceKey(userId, deviceId)] = idpId

proc isOidcDevice*(service: UserService; userId, deviceId: string): bool =
  userDeviceKey(userId, deviceId) in service.oidcDevices

proc getOidcDeviceIdp*(service: UserService; userId, deviceId: string): Option[string] =
  let key = userDeviceKey(userId, deviceId)
  if key in service.oidcDevices:
    some(service.oidcDevices[key])
  else:
    none(string)

proc allowCrossSigningReplacement*(service: var UserService; userId: string; nowMs: uint64): uint64 =
  result = nowMs + 600_000'u64
  service.crossSigningReplacementUntil[userId] = result

proc canReplaceCrossSigningKeys*(service: var UserService; userId: string; nowMs: uint64): bool =
  if userId notin service.crossSigningReplacementUntil:
    return false
  let expiresAt = service.crossSigningReplacementUntil[userId]
  if nowMs < expiresAt:
    return true
  service.crossSigningReplacementUntil.del(userId)
  false

proc getDevicelistVersion*(service: UserService; userId: string): uint64 =
  service.devicelistVersions.getOrDefault(userId, 0'u64)

proc allDevicesMetadata*(service: UserService; userId: string): seq[DeviceRecord] =
  result = @[]
  for device in service.devices.values:
    if device.userId == userId:
      result.add(device)
  result.sort(proc(a, b: DeviceRecord): int = cmp(a.deviceId, b.deviceId))

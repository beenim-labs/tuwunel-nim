const
  RustPath* = "service/users/keys.rs"
  RustCrate* = "service"

import std/[algorithm, json, strutils, tables]

import service/users/device

proc algorithmFromKeyId*(keyId: string): string =
  let colon = keyId.find(':')
  if colon > 0:
    keyId[0 ..< colon]
  else:
    keyId

proc oneTimeKeyStorageKey(userId, deviceId, keyId: string): string =
  userDeviceKey(userId, deviceId) & "\0" & keyId

proc fallbackStorageKey(userId, deviceId, algorithm: string): string =
  userDeviceKey(userId, deviceId) & "\0" & algorithm

proc addOneTimeKey*(
  service: var UserService;
  userId, deviceId, keyId: string;
  key: JsonNode;
): UserResult =
  if not service.deviceExists(userId, deviceId):
    return userError("M_NOT_FOUND", "User does not exist or device has no metadata.")
  if key.isNil:
    return userError("M_BAD_JSON", "One-time key JSON is required.")
  service.oneTimeKeys[oneTimeKeyStorageKey(userId, deviceId, keyId)] = OneTimeKeyRecord(
    userId: userId,
    deviceId: deviceId,
    keyId: keyId,
    key: key.copy(),
  )
  service.lastOneTimeKeyUpdate[userId] = service.nextStreamPos()
  okResult()

proc addOneTimeKeys*(
  service: var UserService;
  userId, deviceId: string;
  keys: openArray[tuple[keyId: string, key: JsonNode]];
): UserResult =
  for item in keys:
    let added = service.addOneTimeKey(userId, deviceId, item.keyId, item.key)
    if not added.ok:
      return added
  okResult()

proc countOneTimeKeys*(service: UserService; userId, deviceId: string): Table[string, int] =
  result = initTable[string, int]()
  for record in service.oneTimeKeys.values:
    if record.userId == userId and record.deviceId == deviceId:
      let algorithm = algorithmFromKeyId(record.keyId)
      result[algorithm] = result.getOrDefault(algorithm, 0) + 1

proc claimOneTimeKey*(
  service: var UserService;
  userId, deviceId, algorithm: string;
): tuple[ok: bool, keyId: string, key: JsonNode] =
  var matches: seq[string] = @[]
  for storageKey, record in service.oneTimeKeys:
    if record.userId == userId and record.deviceId == deviceId and algorithmFromKeyId(record.keyId) == algorithm:
      matches.add(storageKey)
  matches.sort(system.cmp[string])
  if matches.len == 0:
    return (false, "", newJObject())
  let record = service.oneTimeKeys[matches[0]]
  service.oneTimeKeys.del(matches[0])
  (true, record.keyId, record.key.copy())

proc addFallbackKey*(
  service: var UserService;
  userId, deviceId, keyId: string;
  key: JsonNode;
): UserResult =
  if not service.deviceExists(userId, deviceId):
    return userError("M_NOT_FOUND", "User does not exist or device has no metadata.")
  if key.isNil:
    return userError("M_BAD_JSON", "Fallback key JSON is required.")
  let algorithm = algorithmFromKeyId(keyId)
  service.fallbackKeys[fallbackStorageKey(userId, deviceId, algorithm)] = FallbackKeyRecord(
    userId: userId,
    deviceId: deviceId,
    algorithm: algorithm,
    keyId: keyId,
    key: key.copy(),
    used: false,
  )
  service.lastOneTimeKeyUpdate[userId] = service.nextStreamPos()
  okResult()

proc addFallbackKeys*(
  service: var UserService;
  userId, deviceId: string;
  keys: openArray[tuple[keyId: string, key: JsonNode]];
): UserResult =
  for item in keys:
    let added = service.addFallbackKey(userId, deviceId, item.keyId, item.key)
    if not added.ok:
      return added
  okResult()

proc takeFallbackKey*(
  service: var UserService;
  userId, deviceId, algorithm: string;
): tuple[ok: bool, keyId: string, key: JsonNode] =
  let key = fallbackStorageKey(userId, deviceId, algorithm)
  if key notin service.fallbackKeys:
    return (false, "", newJObject())
  var record = service.fallbackKeys[key]
  record.used = true
  service.fallbackKeys[key] = record
  (true, record.keyId, record.key.copy())

proc unusedFallbackKeyAlgorithms*(service: UserService; userId, deviceId: string): seq[string] =
  result = @[]
  for record in service.fallbackKeys.values:
    if record.userId == userId and record.deviceId == deviceId and not record.used:
      result.add(record.algorithm)
  result.sort(system.cmp[string])

proc lastOneTimeKeysUpdate*(service: UserService; userId: string): uint64 =
  service.lastOneTimeKeyUpdate.getOrDefault(userId, 0'u64)

proc addDeviceKeys*(
  service: var UserService;
  userId, deviceId: string;
  keys: JsonNode;
): UserResult =
  if not service.deviceExists(userId, deviceId):
    return userError("M_NOT_FOUND", "Device not found.")
  service.deviceKeys[userDeviceKey(userId, deviceId)] = DeviceKeyRecord(
    userId: userId,
    deviceId: deviceId,
    keys: if keys.isNil: newJObject() else: keys.copy(),
    streamPos: service.nextStreamPos(),
  )
  discard service.bumpDeviceList(userId)
  okResult()

proc getDeviceKeys*(service: UserService; userId, deviceId: string): tuple[ok: bool, keys: JsonNode] =
  let key = userDeviceKey(userId, deviceId)
  if key notin service.deviceKeys:
    return (false, newJObject())
  (true, service.deviceKeys[key].keys.copy())

proc addCrossSigningKey*(
  service: var UserService;
  userId, keyType: string;
  key: JsonNode;
): UserResult =
  if userId notin service.users:
    return userError("M_NOT_FOUND", "User not found.")
  service.crossSigningKeys[userId & "\0" & keyType] = CrossSigningKeyRecord(
    userId: userId,
    keyType: keyType,
    key: if key.isNil: newJObject() else: key.copy(),
  )
  discard service.bumpDeviceList(userId)
  okResult()

proc getCrossSigningKey*(service: UserService; userId, keyType: string): tuple[ok: bool, key: JsonNode] =
  let storageKey = userId & "\0" & keyType
  if storageKey notin service.crossSigningKeys:
    return (false, newJObject())
  (true, service.crossSigningKeys[storageKey].key.copy())

proc markDeviceKeyUpdate*(service: var UserService; userId: string): uint64 =
  discard service.bumpDeviceList(userId)
  service.deviceListUpdates[userId].streamPos

proc deviceListChangesSince*(service: UserService; since: uint64): seq[string] =
  result = @[]
  for update in service.deviceListUpdates.values:
    if update.streamPos > since:
      result.add(update.userId)
  result.sort(system.cmp[string])

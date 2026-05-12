import std/[json, tables]

import core/matrix/server_signing

const
  RustPath* = "service/server_keys/get.rs"
  RustCrate* = "service"

type
  OldVerifyKey* = object
    expiredTs*: int64
    key*: seq[byte]

  ServerSigningKeys* = object
    serverName*: string
    validUntilTs*: int64
    verifyKeys*: Table[string, seq[byte]]
    oldVerifyKeys*: Table[string, OldVerifyKey]

  ServerSigningKeyCache* = object
    byServer*: Table[string, ServerSigningKeys]

proc initServerSigningKeyCache*(): ServerSigningKeyCache =
  ServerSigningKeyCache(byServer: initTable[string, ServerSigningKeys]())

proc copyBytes(data: openArray[byte]): seq[byte] =
  result = newSeq[byte](data.len)
  for idx, value in data:
    result[idx] = value

proc parseVerifyKeyMap(
    node: JsonNode
): tuple[ok: bool, keys: Table[string, seq[byte]], err: string] =
  result = (true, initTable[string, seq[byte]](), "")
  if node.kind == JNull:
    return
  if node.kind != JObject:
    return (false, initTable[string, seq[byte]](), "verify_keys must be an object")
  for keyId, keyNode in node:
    let keyText = keyNode{"key"}.getStr("")
    let decoded = decodeUnpaddedBase64(keyText)
    if not decoded.ok:
      return (false, initTable[string, seq[byte]](), "invalid verify key " & keyId & ": " & decoded.err)
    result.keys[keyId] = decoded.data

proc parseOldVerifyKeyMap(
    node: JsonNode
): tuple[ok: bool, keys: Table[string, OldVerifyKey], err: string] =
  result = (true, initTable[string, OldVerifyKey](), "")
  if node.kind == JNull:
    return
  if node.kind != JObject:
    return (false, initTable[string, OldVerifyKey](), "old_verify_keys must be an object")
  for keyId, keyNode in node:
    let keyText = keyNode{"key"}.getStr("")
    let decoded = decodeUnpaddedBase64(keyText)
    if not decoded.ok:
      return (false, initTable[string, OldVerifyKey](), "invalid old verify key " & keyId & ": " & decoded.err)
    result.keys[keyId] = OldVerifyKey(
      expiredTs: keyNode{"expired_ts"}.getInt(0).int64,
      key: decoded.data,
    )

proc serverSigningKeysFromJson*(
    payload: JsonNode
): tuple[ok: bool, keys: ServerSigningKeys, err: string] =
  if payload.kind != JObject:
    return (false, ServerSigningKeys(), "server signing keys payload must be an object")

  let serverName = payload{"server_name"}.getStr("")
  if serverName.len == 0:
    return (false, ServerSigningKeys(), "server_name is required")

  let verifyKeys = parseVerifyKeyMap(payload{"verify_keys"})
  if not verifyKeys.ok:
    return (false, ServerSigningKeys(), verifyKeys.err)

  let oldVerifyKeys = parseOldVerifyKeyMap(payload{"old_verify_keys"})
  if not oldVerifyKeys.ok:
    return (false, ServerSigningKeys(), oldVerifyKeys.err)

  (
    true,
    ServerSigningKeys(
      serverName: serverName,
      validUntilTs: payload{"valid_until_ts"}.getInt(0).int64,
      verifyKeys: verifyKeys.keys,
      oldVerifyKeys: oldVerifyKeys.keys,
    ),
    "",
  )

proc addSigningKeys*(cache: var ServerSigningKeyCache; keys: ServerSigningKeys) =
  if keys.serverName.len == 0:
    return
  if keys.serverName notin cache.byServer:
    cache.byServer[keys.serverName] = ServerSigningKeys(
      serverName: keys.serverName,
      validUntilTs: keys.validUntilTs,
      verifyKeys: initTable[string, seq[byte]](),
      oldVerifyKeys: initTable[string, OldVerifyKey](),
    )
  var current = cache.byServer[keys.serverName]
  current.validUntilTs = max(current.validUntilTs, keys.validUntilTs)
  for keyId, key in keys.verifyKeys:
    current.verifyKeys[keyId] = copyBytes(key)
  for keyId, key in keys.oldVerifyKeys:
    current.oldVerifyKeys[keyId] = OldVerifyKey(
      expiredTs: key.expiredTs,
      key: copyBytes(key.key),
    )
  cache.byServer[keys.serverName] = current

proc verifyKeyExists*(cache: ServerSigningKeyCache; serverName, keyId: string): bool =
  if serverName notin cache.byServer:
    return false
  let keys = cache.byServer[serverName]
  keyId in keys.verifyKeys or keyId in keys.oldVerifyKeys

proc verifyKeysFor*(
    cache: ServerSigningKeyCache;
    serverName: string
): Table[string, seq[byte]] =
  result = initTable[string, seq[byte]]()
  if serverName notin cache.byServer:
    return
  let keys = cache.byServer[serverName]
  for keyId, key in keys.verifyKeys:
    result[keyId] = copyBytes(key)
  for keyId, key in keys.oldVerifyKeys:
    if keyId notin result:
      result[keyId] = copyBytes(key.key)

proc getVerifyKey*(
    cache: ServerSigningKeyCache;
    serverName, keyId: string
): tuple[ok: bool, key: seq[byte], err: string] =
  if serverName notin cache.byServer:
    return (false, @[], "server signing keys are missing for " & serverName)
  let keys = cache.byServer[serverName]
  if keyId in keys.verifyKeys:
    return (true, copyBytes(keys.verifyKeys[keyId]), "")
  if keyId in keys.oldVerifyKeys:
    return (true, copyBytes(keys.oldVerifyKeys[keyId].key), "")
  (false, @[], "server signing key is missing for " & serverName & " " & keyId)

const
  RustPath* = "api/client/voip.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/[base64, json, os, sha1, strutils, times]
import core/config_values

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

proc getConfigStringArray(cfg: FlatConfig; key: string): seq[string] =
  result = @[]
  if key notin cfg:
    return
  let value = cfg[key]
  case value.kind
  of cvArray:
    for item in value.items:
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
    result.add(value.s)
  else:
    discard

proc getConfigStringArray(cfg: FlatConfig; keys: openArray[string]): seq[string] =
  result = @[]
  for key in keys:
    result.add(getConfigStringArray(cfg, key))

proc nowMs(): int64 =
  (epochTime() * 1000).int64

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

proc turnServerPayload*(
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
        "@turn_" & $(nowMs() mod 1000000000'i64) & ":" & serverName
    username = $expiry & ":" & turnUser
    password = hmacSha1Base64(secret, username)

  (true, %*{
    "uris": uris,
    "username": username,
    "password": password,
    "ttl": ttl
  })

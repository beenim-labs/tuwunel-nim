import std/[json, tables]

import service/server_keys/get
import service/server_keys/request

const
  RustPath* = "service/server_keys/acquire.rs"
  RustCrate* = "service"

type
  ServerKeyRef* = object
    serverName*: string
    keyId*: string

proc serverKeyRef*(serverName, keyId: string): ServerKeyRef =
  ServerKeyRef(serverName: serverName, keyId: keyId)

proc missingKeys*(
    cache: ServerSigningKeyCache;
    requested: openArray[ServerKeyRef]
): seq[ServerKeyRef] =
  result = @[]
  for item in requested:
    if item.serverName.len == 0 or item.keyId.len == 0:
      continue
    if not cache.verifyKeyExists(item.serverName, item.keyId):
      result.add(item)

proc acquireFromResponse*(
    cache: var ServerSigningKeyCache;
    payload: JsonNode
): tuple[ok: bool, added: int, err: string] =
  let parsed = serverSigningKeysFromResponse(payload)
  if not parsed.ok:
    return (false, 0, parsed.err)

  var added = 0
  for keys in parsed.keys:
    let before = len(cache.verifyKeysFor(keys.serverName))
    cache.addSigningKeys(keys)
    let after = len(cache.verifyKeysFor(keys.serverName))
    if after > before:
      inc added, after - before
  (true, added, "")

import std/[json, uri]

import service/server_keys/get

const
  RustPath* = "service/server_keys/request.rs"
  RustCrate* = "service"

proc originServerKeysPath*(keyId = ""): string =
  if keyId.len == 0:
    "/_matrix/key/v2/server"
  else:
    "/_matrix/key/v2/server/" & encodeUrl(keyId)

proc notaryServerKeysPath*(serverName: string): string =
  "/_matrix/key/v2/query/" & encodeUrl(serverName)

proc serverKeyQueryPayload*(
    serverName, keyId: string;
    minimumValidUntilTs: int64
): JsonNode =
  let criteria =
    if minimumValidUntilTs > 0:
      %*{"minimum_valid_until_ts": minimumValidUntilTs}
    else:
      newJObject()
  %*{
    "server_keys": {
      serverName: {
        keyId: criteria
      }
    }
  }

proc serverSigningKeysFromResponse*(
    payload: JsonNode
): tuple[ok: bool, keys: seq[ServerSigningKeys], err: string] =
  if payload.kind != JObject:
    return (false, @[], "server key response must be an object")

  if payload.hasKey("server_keys"):
    if payload["server_keys"].kind != JArray:
      return (false, @[], "server_keys must be an array")
    var keys = newSeq[ServerSigningKeys]()
    for item in payload["server_keys"]:
      let parsed = serverSigningKeysFromJson(item)
      if not parsed.ok:
        return (false, @[], parsed.err)
      keys.add(parsed.keys)
    return (true, keys, "")

  let parsed = serverSigningKeysFromJson(payload)
  if not parsed.ok:
    return (false, @[], parsed.err)
  (true, @[parsed.keys], "")

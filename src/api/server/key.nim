import std/json

import core/matrix/server_signing

const
  RustPath* = "api/server/key.rs"
  RustCrate* = "api"

proc serverKeysPayload*(
    serverName, keyId: string;
    privateSeed, publicKey: openArray[byte];
    validUntilTs: int64
): tuple[ok: bool, payload: JsonNode, err: string] =
  signedServerKeysPayload(serverName, keyId, privateSeed, publicKey, validUntilTs)

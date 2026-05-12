import std/json

import core/matrix/server_signing
import service/server_keys/keypair

const
  RustPath* = "service/server_keys/sign.rs"
  RustCrate* = "service"

proc signJsonWithKeypair*(
    payload: JsonNode;
    serverName: string;
    keypair: ServerSigningKeypair
): tuple[ok: bool, payload: JsonNode, err: string] =
  signJson(payload, serverName, keypair.keyId, keypair.seed)

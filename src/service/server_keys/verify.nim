import std/json

import core/crypto/ed25519
import core/matrix/server_signing

const
  RustPath* = "service/server_keys/verify.rs"
  RustCrate* = "service"

proc verifyJsonSignature*(
    payload: JsonNode;
    signerName, keyId: string;
    publicKey: openArray[byte]
): bool =
  if payload.kind != JObject:
    return false
  let signatureText = payload{"signatures"}{signerName}{keyId}.getStr("")
  if signatureText.len == 0:
    return false

  let canonical = canonicalSigningString(payload)
  if not canonical.ok:
    return false

  let signature = decodeUnpaddedBase64(signatureText)
  if not signature.ok:
    return false

  ed25519.verify(publicKey, canonical.value, signature.data)

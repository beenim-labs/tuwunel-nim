import std/[base64, json, strutils]

import core/crypto/ed25519
import core/utils/json as json_utils

const
  RustPath* = "api/server/key.rs"
  RustCrate* = "api"

proc bytesToString(data: openArray[byte]): string =
  result = newString(data.len)
  for idx, value in data:
    result[idx] = char(value)

proc stringToBytes(value: string): seq[byte] =
  result = newSeq[byte](value.len)
  for idx, ch in value:
    result[idx] = byte(ch)

proc encodeUnpaddedBase64*(data: openArray[byte]): string =
  result = encode(bytesToString(data))
  while result.len > 0 and result[^1] == '=':
    result.setLen(result.len - 1)

proc decodeUnpaddedBase64*(value: string): tuple[ok: bool, data: seq[byte], err: string] =
  var normalized = value.strip()
  while normalized.len mod 4 != 0:
    normalized.add('=')
  try:
    (true, stringToBytes(decode(normalized)), "")
  except CatchableError as e:
    (false, @[], "base64 decode failed: " & e.msg)

proc canonicalSigningString*(payload: JsonNode): tuple[ok: bool, value: string, err: string] =
  if payload.kind != JObject:
    return (false, "", "signed Matrix JSON must be an object")

  var unsignedPayload = payload.copy()
  if unsignedPayload.hasKey("signatures"):
    unsignedPayload.delete("signatures")
  if unsignedPayload.hasKey("unsigned"):
    unsignedPayload.delete("unsigned")

  let canonical = json_utils.toCanonicalObject(unsignedPayload)
  if not canonical.ok:
    return (false, "", canonical.message)
  (true, $canonical.value, "")

proc signJson*(
    payload: JsonNode;
    signerName, keyId: string;
    privateSeed: openArray[byte]
): tuple[ok: bool, payload: JsonNode, err: string] =
  var signedPayload = payload.copy()
  let canonical = canonicalSigningString(signedPayload)
  if not canonical.ok:
    return (false, newJObject(), canonical.err)

  let signature = ed25519.sign(privateSeed, canonical.value)
  if not signature.ok:
    return (false, newJObject(), signature.err)

  if not signedPayload.hasKey("signatures") or signedPayload["signatures"].kind != JObject:
    signedPayload["signatures"] = newJObject()
  if not signedPayload["signatures"].hasKey(signerName) or
      signedPayload["signatures"][signerName].kind != JObject:
    signedPayload["signatures"][signerName] = newJObject()
  signedPayload["signatures"][signerName][keyId] = %encodeUnpaddedBase64(signature.signature)
  (true, signedPayload, "")

proc signedServerKeysPayload*(
    serverName, keyId: string;
    privateSeed, publicKey: openArray[byte];
    validUntilTs: int64
): tuple[ok: bool, payload: JsonNode, err: string] =
  let payload = %*{
    "server_name": serverName,
    "valid_until_ts": validUntilTs,
    "verify_keys": {
      keyId: {
        "key": encodeUnpaddedBase64(publicKey)
      }
    },
    "old_verify_keys": {}
  }
  signJson(payload, serverName, keyId, privateSeed)

const
  RustPath* = "api/client/keys.rs"
  RustCrate* = "api"

import std/json

type
  KeyPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc splitKeyId*(raw: string): tuple[ok: bool, algorithm: string, keyId: string] =
  let sep = raw.find(':')
  if sep <= 0 or sep >= raw.high:
    return (false, "", "")
  (true, raw[0 ..< sep], raw[sep + 1 .. ^1])

proc uploadKeysPolicy*(deviceId: string; body: JsonNode): KeyPolicyResult =
  if deviceId.len == 0:
    return (false, "M_INVALID_PARAM", "Device id is required for key upload.")
  if body.isNil or body.kind != JObject:
    return (false, "M_BAD_JSON", "Invalid JSON body.")
  for field in ["device_keys", "one_time_keys", "fallback_keys"]:
    if body.hasKey(field) and body[field].kind != JObject:
      return (false, "M_BAD_JSON", field & " must be an object.")
  (true, "", "")

proc uploadKeysResponse*(oneTimeKeyCounts, unusedFallbackKeyTypes: JsonNode): JsonNode =
  %*{
    "one_time_key_counts": if oneTimeKeyCounts.isNil: newJObject() else: oneTimeKeyCounts.copy(),
    "device_unused_fallback_key_types": if unusedFallbackKeyTypes.isNil: newJArray() else: unusedFallbackKeyTypes.copy(),
  }

proc fallbackDeviceKey*(userId, deviceId: string): JsonNode =
  %*{
    "user_id": userId,
    "device_id": deviceId,
    "algorithms": [],
    "keys": {},
    "signatures": {},
  }

proc queryKeysResponse*(
  deviceKeys: JsonNode;
  masterKeys = newJObject();
  selfSigningKeys = newJObject();
  userSigningKeys = newJObject();
): JsonNode =
  %*{
    "device_keys": if deviceKeys.isNil: newJObject() else: deviceKeys.copy(),
    "failures": {},
    "master_keys": masterKeys.copy(),
    "self_signing_keys": selfSigningKeys.copy(),
    "user_signing_keys": userSigningKeys.copy(),
  }

proc claimKeysResponse*(oneTimeKeys: JsonNode): JsonNode =
  %*{
    "one_time_keys": if oneTimeKeys.isNil: newJObject() else: oneTimeKeys.copy(),
    "failures": {},
  }

proc keyChangesResponse*(changed, left: JsonNode): JsonNode =
  %*{
    "changed": if changed.isNil: newJArray() else: changed.copy(),
    "left": if left.isNil: newJArray() else: left.copy(),
  }

proc uploadSigningKeysPolicy*(body: JsonNode): KeyPolicyResult =
  if body.isNil or body.kind != JObject:
    return (false, "M_BAD_JSON", "Invalid JSON body.")
  for field in ["master_key", "self_signing_key", "user_signing_key"]:
    if body.hasKey(field) and body[field].kind != JObject:
      return (false, "M_BAD_JSON", field & " must be an object.")
  (true, "", "")

proc signaturesUploadResponse*(): JsonNode =
  %*{"failures": {}}

proc signingKeysUploadResponse*(): JsonNode =
  newJObject()

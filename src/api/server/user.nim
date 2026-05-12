const
  RustPath* = "api/server/user.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/[json, strutils]

proc userDevicesPayload*(
    userId: string;
    streamId: int64;
    devices: JsonNode;
    masterKey: JsonNode = nil;
    selfSigningKey: JsonNode = nil
): tuple[ok: bool, payload: JsonNode] =
  if userId.strip().len == 0 or devices.isNil or devices.kind != JArray:
    return (false, newJObject())

  result = (true, %*{
    "user_id": userId,
    "stream_id": max(0'i64, streamId),
    "devices": devices
  })
  if not masterKey.isNil and masterKey.kind == JObject:
    result.payload["master_key"] = masterKey
  if not selfSigningKey.isNil and selfSigningKey.kind == JObject:
    result.payload["self_signing_key"] = selfSigningKey

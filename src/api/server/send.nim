const
  RustPath* = "api/server/send.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/json

proc sendTransactionPayload*(pduResults: JsonNode): tuple[ok: bool, payload: JsonNode] =
  if pduResults.isNil or pduResults.kind != JObject:
    return (false, newJObject())
  (true, %*{"pdus": pduResults})

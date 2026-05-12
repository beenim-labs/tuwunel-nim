const
  RustPath* = "api/server/event_auth.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/json

proc eventAuthPayload*(authChain: JsonNode): tuple[ok: bool, payload: JsonNode] =
  if authChain.isNil or authChain.kind != JArray:
    return (false, newJObject())
  (true, %*{"auth_chain": authChain})

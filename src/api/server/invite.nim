const
  RustPath* = "api/server/invite.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/json

proc invitePayload*(event: JsonNode): tuple[ok: bool, payload: JsonNode] =
  if event.isNil or event.kind != JObject:
    return (false, newJObject())
  (true, %*{"event": event})

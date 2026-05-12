const
  RustPath* = "api/server/make_leave.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/[json, strutils]

proc makeLeavePayload*(
    roomVersion: string;
    event: JsonNode
): tuple[ok: bool, payload: JsonNode] =
  if roomVersion.strip().len == 0 or event.isNil or event.kind != JObject:
    return (false, newJObject())
  (true, %*{
    "room_version": roomVersion,
    "event": event
  })

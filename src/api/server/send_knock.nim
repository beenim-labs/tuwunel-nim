const
  RustPath* = "api/server/send_knock.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/json

proc sendKnockPayload*(knockRoomState: JsonNode): tuple[ok: bool, payload: JsonNode] =
  if knockRoomState.isNil or knockRoomState.kind != JArray:
    return (false, newJObject())
  (true, %*{"knock_room_state": knockRoomState})

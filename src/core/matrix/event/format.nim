const
  RustPath* = "core/matrix/event/format.rs"
  RustCrate* = "core"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/json

import core/matrix/event/redact

proc timelineEventFormat*(event: JsonNode; includeRoomId = true): JsonNode =
  result = newJObject()
  if event.isNil or event.kind != JObject:
    return

  let copied = copyRedactsForClient(event)
  result["content"] = copied.content
  for key in ["event_id", "origin_server_ts", "sender", "state_key", "type", "unsigned"]:
    if event.hasKey(key):
      result[key] = event[key].copy()
  if includeRoomId and event.hasKey("room_id"):
    result["room_id"] = event["room_id"].copy()
  if copied.redacts.len > 0:
    result["redacts"] = %copied.redacts

proc strippedStateEventFormat*(event: JsonNode): JsonNode =
  result = newJObject()
  if event.isNil or event.kind != JObject:
    return
  for key in ["content", "sender", "state_key", "type"]:
    if event.hasKey(key):
      result[key] = event[key].copy()

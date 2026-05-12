const
  RustPath* = "api/server/publicrooms.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/json

proc publicRoomsPayload*(
    chunk: JsonNode;
    totalRoomCountEstimate: int;
    nextBatch = "";
    prevBatch = ""
): tuple[ok: bool, payload: JsonNode] =
  if chunk.isNil or chunk.kind != JArray:
    return (false, newJObject())

  result = (true, %*{
    "chunk": chunk,
    "total_room_count_estimate": max(0, totalRoomCountEstimate)
  })
  if prevBatch.len > 0:
    result.payload["prev_batch"] = %prevBatch
  if nextBatch.len > 0:
    result.payload["next_batch"] = %nextBatch

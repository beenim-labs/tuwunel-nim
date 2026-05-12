const
  RustPath* = "api/server/hierarchy.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/json

proc hierarchyPayload*(
    rooms: JsonNode;
    nextBatch = "";
    inaccessibleChildren: JsonNode = nil
): tuple[ok: bool, payload: JsonNode] =
  if rooms.isNil or rooms.kind != JArray:
    return (false, newJObject())

  result = (true, %*{
    "rooms": rooms,
    "next_batch": nextBatch
  })
  if not inaccessibleChildren.isNil and inaccessibleChildren.kind == JArray:
    result.payload["inaccessible_children"] = inaccessibleChildren

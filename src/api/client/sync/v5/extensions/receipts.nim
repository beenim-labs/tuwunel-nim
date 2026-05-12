const
  RustPath* = "api/client/sync/v5/extensions/receipts.rs"
  RustCrate* = "api"

import std/[json, tables]

proc receiptsPayload*(
  rooms: Table[string, JsonNode] = initTable[string, JsonNode]()
): JsonNode =
  result = %*{"rooms": {}}
  for roomId, event in rooms:
    result["rooms"][roomId] = if event.isNil: newJObject() else: event.copy()

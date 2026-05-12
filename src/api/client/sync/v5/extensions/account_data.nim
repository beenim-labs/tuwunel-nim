const
  RustPath* = "api/client/sync/v5/extensions/account_data.rs"
  RustCrate* = "api"

import std/[json, tables]

proc accountDataPayload*(
  global: openArray[JsonNode] = [];
  rooms: Table[string, seq[JsonNode]] = initTable[string, seq[JsonNode]]()
): JsonNode =
  result = %*{
    "global": [],
    "rooms": {}
  }
  for event in global:
    result["global"].add(if event.isNil: newJObject() else: event.copy())
  for roomId, events in rooms:
    result["rooms"][roomId] = newJArray()
    for event in events:
      result["rooms"][roomId].add(if event.isNil: newJObject() else: event.copy())

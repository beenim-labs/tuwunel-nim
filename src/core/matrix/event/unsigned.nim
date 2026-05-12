const
  RustPath* = "core/matrix/event/unsigned.rs"
  RustCrate* = "core"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/json

proc unsignedAsValue*(event: JsonNode): JsonNode =
  if event.isNil or event.kind != JObject:
    return newJObject()
  let unsigned = event{"unsigned"}
  if unsigned.kind == JObject:
    unsigned.copy()
  else:
    newJObject()

proc containsUnsignedProperty*(
    event: JsonNode;
    property: string;
    expectedKind: JsonNodeKind
): bool =
  let unsigned = unsignedAsValue(event)
  unsigned.kind == JObject and unsigned.hasKey(property) and unsigned[property].kind == expectedKind

proc getUnsignedProperty*(event: JsonNode; property: string): tuple[ok: bool, value: JsonNode] =
  let unsigned = unsignedAsValue(event)
  if unsigned.kind != JObject or not unsigned.hasKey(property):
    return (false, newJNull())
  (true, unsigned[property].copy())

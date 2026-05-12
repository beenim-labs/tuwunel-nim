const
  RustPath* = "core/matrix/event/relation.rs"
  RustCrate* = "core"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/json

proc relationType*(event: JsonNode): string =
  if event.isNil or event.kind != JObject:
    return ""
  let content = event{"content"}
  if content.kind != JObject:
    return ""
  let relatesTo = content{"m.relates_to"}
  if relatesTo.kind != JObject:
    return ""
  relatesTo{"rel_type"}.getStr("")

proc relationTypeEqual*(event: JsonNode; expected: string): bool =
  relationType(event) == expected

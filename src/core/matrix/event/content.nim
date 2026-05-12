const
  RustPath* = "core/matrix/event/content.rs"
  RustCrate* = "core"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/json

proc contentAsValue*(event: JsonNode): JsonNode =
  if event.isNil or event.kind != JObject:
    return newJObject()
  let content = event{"content"}
  if content.kind == JObject:
    content.copy()
  else:
    newJObject()

proc getContentProperty*(event: JsonNode; property: string): tuple[ok: bool, value: JsonNode] =
  let content = contentAsValue(event)
  if content.kind != JObject or not content.hasKey(property):
    return (false, newJNull())
  (true, content[property].copy())

const
  RustPath* = "core/matrix/event/redact.rs"
  RustCrate* = "core"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/[json, strutils]

proc redactsFromContent*(event: JsonNode): string =
  event{"content"}{"redacts"}.getStr("")

proc topLevelRedacts*(event: JsonNode): string =
  event{"redacts"}.getStr("")

proc isRedactionEvent*(event: JsonNode): bool =
  event{"type"}.getStr("") == "m.room.redaction"

proc copyRedactsForClient*(event: JsonNode): tuple[redacts: string, content: JsonNode] =
  result = ("", newJObject())
  if event.isNil or event.kind != JObject:
    return

  result.redacts = topLevelRedacts(event)
  let content =
    if event{"content"}.kind == JObject:
      event["content"].copy()
    else:
      newJObject()

  if not isRedactionEvent(event):
    result.content = content
    return

  let contentRedacts = content{"redacts"}.getStr("")
  if contentRedacts.len > 0:
    result.redacts = contentRedacts
    result.content = content
    return

  if result.redacts.len > 0:
    content["redacts"] = %result.redacts
  result.content = content

proc isRedacted*(event: JsonNode): bool =
  event{"unsigned"}{"redacted_because"}.kind == JObject

proc redactsId*(event: JsonNode; contentFieldRedacts: bool): string =
  if not isRedactionEvent(event):
    return ""
  if contentFieldRedacts:
    redactsFromContent(event)
  else:
    topLevelRedacts(event)

proc roomVersionContentFieldRedacts*(roomVersion: string): bool =
  try:
    parseInt(roomVersion) >= 11
  except ValueError:
    true

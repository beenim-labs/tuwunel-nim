const
  RustPath* = "core/matrix/event/filter.rs"
  RustCrate* = "core"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/[json, options]

type
  RoomEventFilter* = object
    rooms*: seq[string]
    notRooms*: seq[string]
    senders*: seq[string]
    notSenders*: seq[string]
    types*: seq[string]
    notTypes*: seq[string]
    urlFilter*: Option[bool]

proc matchesAnyAllowed(value: string; allowed: seq[string]): bool =
  allowed.len == 0 or value in allowed

proc matchesEvent*(filter: RoomEventFilter; event: JsonNode): bool =
  if event.isNil or event.kind != JObject:
    return false

  let roomId = event{"room_id"}.getStr("")
  let sender = event{"sender"}.getStr("")
  let eventType = event{"type"}.getStr("")

  if roomId in filter.notRooms or sender in filter.notSenders or eventType in filter.notTypes:
    return false
  if not matchesAnyAllowed(roomId, filter.rooms):
    return false
  if not matchesAnyAllowed(sender, filter.senders):
    return false
  if not matchesAnyAllowed(eventType, filter.types):
    return false
  if filter.urlFilter.isSome:
    let content = event{"content"}
    let hasUrl = content.kind == JObject and content.hasKey("url") and content["url"].kind == JString
    if hasUrl != filter.urlFilter.get():
      return false
  true

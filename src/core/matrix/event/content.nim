## Event content extraction helpers.
##
## Ported from Rust core/matrix/event/content.rs — provides utilities for
## extracting and deserializing event content from JSON.

import std/[json, options]
import ../event

const
  RustPath* = "core/matrix/event/content.rs"
  RustCrate* = "core"

proc getContentField*(event: Event; field: string): Option[JsonNode] =
  ## Get a specific field from the event content.
  let content = event.getContentAsValue()
  if content.kind == JObject and content.hasKey(field):
    some(content[field])
  else:
    none(JsonNode)

proc getContentString*(event: Event; field: string): Option[string] =
  ## Get a string field from event content.
  let val = event.getContentField(field)
  if val.isSome and val.get().kind == JString:
    some(val.get().getStr())
  else:
    none(string)

proc getContentBool*(event: Event; field: string): Option[bool] =
  ## Get a boolean field from event content.
  let val = event.getContentField(field)
  if val.isSome and val.get().kind == JBool:
    some(val.get().getBool())
  else:
    none(bool)

proc getContentInt*(event: Event; field: string): Option[int64] =
  ## Get an integer field from event content.
  let val = event.getContentField(field)
  if val.isSome and val.get().kind == JInt:
    some(val.get().getBiggestInt())
  else:
    none(int64)

proc getMembership*(event: Event): string =
  ## Extract membership value from m.room.member event content.
  if event.eventType != "m.room.member":
    return ""
  event.getContentString("membership").get("")

proc getJoinRule*(event: Event): string =
  ## Extract join_rule value from m.room.join_rules event content.
  if event.eventType != "m.room.join_rules":
    return ""
  event.getContentString("join_rule").get("")

proc getRoomName*(event: Event): string =
  ## Extract name from m.room.name event content.
  if event.eventType != "m.room.name":
    return ""
  event.getContentString("name").get("")

proc getRoomTopic*(event: Event): string =
  ## Extract topic from m.room.topic event content.
  if event.eventType != "m.room.topic":
    return ""
  event.getContentString("topic").get("")

proc getAlias*(event: Event): string =
  ## Extract alias from m.room.canonical_alias event content.
  if event.eventType != "m.room.canonical_alias":
    return ""
  event.getContentString("alias").get("")

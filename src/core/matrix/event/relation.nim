## Event relation type handling.
##
## Ported from Rust core/matrix/event/relation.rs — provides checking
## whether an event has a specific relation type (e.g. m.annotation,
## m.thread, m.replace).

import std/[json, options]
import ../event

const
  RustPath* = "core/matrix/event/relation.rs"
  RustCrate* = "core"

type
  ## Matrix event relation types.
  RelationType* = enum
    rtAnnotation = "m.annotation"
    rtThread = "m.thread"
    rtReplace = "m.replace"
    rtReference = "m.reference"
    rtCustom = "custom"

proc getRelationType*(event: Event): Option[RelationType] =
  ## Extract the relation type from an event's content.
  let content = event.getContentAsValue()
  if content.kind != JObject:
    return none(RelationType)
  if not content.hasKey("m.relates_to"):
    return none(RelationType)
  let relatesTo = content["m.relates_to"]
  if relatesTo.kind != JObject or not relatesTo.hasKey("rel_type"):
    return none(RelationType)
  let relType = relatesTo["rel_type"]
  if relType.kind != JString:
    return none(RelationType)
  case relType.getStr()
  of "m.annotation": some(rtAnnotation)
  of "m.thread": some(rtThread)
  of "m.replace": some(rtReplace)
  of "m.reference": some(rtReference)
  else: some(rtCustom)

proc hasRelationType*(event: Event; relType: RelationType): bool =
  ## Check if an event has a specific relation type.
  let eventRelType = event.getRelationType()
  eventRelType.isSome and eventRelType.get() == relType

proc getRelatesTo*(event: Event): Option[string] =
  ## Get the event ID that this event relates to.
  let content = event.getContentAsValue()
  if content.kind != JObject or not content.hasKey("m.relates_to"):
    return none(string)
  let relatesTo = content["m.relates_to"]
  if relatesTo.kind != JObject or not relatesTo.hasKey("event_id"):
    return none(string)
  let eventId = relatesTo["event_id"]
  if eventId.kind == JString:
    some(eventId.getStr())
  else:
    none(string)

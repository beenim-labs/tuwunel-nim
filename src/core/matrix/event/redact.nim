## Event redaction logic.
##
## Ported from Rust core/matrix/event/redact.rs — handles redaction
## detection, redacts ID extraction across room versions, and the
## spec-required copying of the `redacts` property between top-level
## and content for backwards compatibility.

import std/[json, options]
import ../event

const
  RustPath* = "core/matrix/event/redact.rs"
  RustCrate* = "core"

proc copyRedacts*(event: Event):
    tuple[redacts: Option[EventId], content: JsonNode] =
  ## Copy the redacts property between top-level and content for
  ## backwards/forwards compatibility.
  ##
  ## Per spec recommendation:
  ## - For older clients: add redacts to top level of m.room.redaction
  ## - For newer clients: add redacts to content in older room versions
  if event.eventType != "m.room.redaction":
    return (event.redacts, event.getContentAsValue())

  let content = event.getContentAsValue()

  # Check if content has redacts
  if content.kind == JObject and content.hasKey("redacts"):
    let contentRedacts = content["redacts"]
    if contentRedacts.kind == JString:
      return (some(contentRedacts.getStr()), content)

  # If top-level has redacts, copy it to content
  if event.redacts.isSome:
    var newContent = content.copy()
    if newContent.kind != JObject:
      newContent = newJObject()
    newContent["redacts"] = %event.redacts.get()
    return (event.redacts, newContent)

  (event.redacts, content)

proc isEventRedacted*(event: Event): bool =
  ## Check if this event has been redacted by examining unsigned data.
  if event.unsigned.isNone:
    return false
  let u = event.unsigned.get()
  u.kind == JObject and u.hasKey("redacted_because")

proc getRedactsId*(event: Event; roomVersion: RoomVersionId): Option[EventId] =
  ## Get the event ID being redacted.
  ##
  ## For v1-v10: uses the top-level `redacts` property
  ## For v11+: uses the content `redacts` property
  if event.eventType != "m.room.redaction":
    return none(EventId)

  case roomVersion
  of "1", "2", "3", "4", "5", "6", "7", "8", "9", "10":
    event.redacts
  else:
    let content = event.getContentAsValue()
    if content.kind == JObject and content.hasKey("redacts"):
      let r = content["redacts"]
      if r.kind == JString:
        return some(r.getStr())
    # Fallback to top-level
    event.redacts

proc redactEvent*(event: Event; roomVersion: RoomVersionId): Event =
  ## Create a redacted copy of an event, stripping non-spec fields from
  ## content based on the event type.
  ##
  ## Per spec: certain event types preserve specific content keys.
  let allowedKeys = case event.eventType
    of "m.room.member": @["membership", "join_authorised_via_users_server"]
    of "m.room.create": @["creator", "room_version"]
    of "m.room.join_rules": @["join_rule", "allow"]
    of "m.room.power_levels": @["ban", "events", "events_default",
      "invite", "kick", "redact", "state_default", "users",
      "users_default"]
    of "m.room.history_visibility": @["history_visibility"]
    of "m.room.redaction": @["redacts"]
    of "m.room.aliases": @["aliases"]
    else: newSeq[string]()

  var newContent = newJObject()
  if allowedKeys.len > 0:
    let content = event.getContentAsValue()
    if content.kind == JObject:
      for key in allowedKeys:
        if content.hasKey(key):
          newContent[key] = content[key]

  Event(
    eventId: event.eventId,
    roomId: event.roomId,
    sender: event.sender,
    eventType: event.eventType,
    stateKey: event.stateKey,
    content: newContent,
    originServerTs: event.originServerTs,
    unsigned: event.unsigned,
    prevEvents: event.prevEvents,
    authEvents: event.authEvents,
    redacts: event.redacts,
    rejected: event.rejected,
    depth: event.depth,
  )

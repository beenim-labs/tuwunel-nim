## Matrix event types for tuwunel-nim.
##
## Ported from Rust core/matrix/event.rs — defines the core Event type:
## a Matrix PDU (Persistent Data Unit) with all spec-required fields,
## JSON serialization, and helper methods for content extraction,
## filtering, redaction detection, and format conversion.

import std/[json, options, times]

const
  RustPath* = "core/matrix/event.rs"
  RustCrate* = "core"

type
  ## A Matrix event type string (e.g. "m.room.message", "m.room.member").
  TimelineEventType* = string

  ## A state event type string.
  StateEventType* = string

  ## Matrix identifiers as string types.
  EventId* = string
  RoomId* = string
  UserId* = string
  ServerName* = string
  RoomVersionId* = string

  ## Milliseconds since Unix epoch.
  MilliSecondsSinceUnixEpoch* = int64

  ## A Matrix Persistent Data Unit (PDU) / Event.
  Event* = ref object
    eventId*: EventId
    roomId*: RoomId
    sender*: UserId
    eventType*: TimelineEventType
    stateKey*: Option[string]
    content*: JsonNode           ## Event content as JSON
    originServerTs*: MilliSecondsSinceUnixEpoch
    unsigned*: Option[JsonNode]  ## Unsigned metadata
    prevEvents*: seq[EventId]    ## Previous events in the DAG
    authEvents*: seq[EventId]    ## Authenticating events
    redacts*: Option[EventId]    ## Event this redacts (for m.room.redaction)
    rejected*: bool              ## Whether this event was rejected
    depth*: int64                ## Depth in the event graph

# ---------------------------------------------------------------------------
# Constructors
# ---------------------------------------------------------------------------

proc newEvent*(eventId: EventId; roomId: RoomId; sender: UserId;
               eventType: TimelineEventType; content: JsonNode;
               originServerTs: MilliSecondsSinceUnixEpoch = 0;
               stateKey: Option[string] = none(string)): Event =
  ## Create a new Event with required fields.
  let ts = if originServerTs != 0: originServerTs
           else: int64(epochTime() * 1000)
  Event(
    eventId: eventId,
    roomId: roomId,
    sender: sender,
    eventType: eventType,
    content: content,
    originServerTs: ts,
    stateKey: stateKey,
    unsigned: none(JsonNode),
    prevEvents: @[],
    authEvents: @[],
    redacts: none(EventId),
    rejected: false,
    depth: 0,
  )

# ---------------------------------------------------------------------------
# Core methods — ported from Rust Event trait
# ---------------------------------------------------------------------------

proc isTypeAndStateKey*(event: Event; kind: TimelineEventType;
                        stateKey: string): bool =
  ## Check if the event matches a specific type and state key.
  event.eventType == kind and event.stateKey == some(stateKey)

proc kind*(event: Event): TimelineEventType =
  ## Returns the event type.
  event.eventType

proc getContentAsValue*(event: Event): JsonNode =
  ## Get the event content as a JsonNode value.
  if event.content.isNil:
    newJObject()
  else:
    event.content

proc getUnsignedAsValue*(event: Event): JsonNode =
  ## Get the unsigned data as a JsonNode value.
  if event.unsigned.isSome:
    event.unsigned.get()
  else:
    newJObject()

proc containsUnsignedProperty*(event: Event; property: string): bool =
  ## Check if unsigned data contains a specific property.
  if event.unsigned.isNone:
    return false
  let u = event.unsigned.get()
  u.kind == JObject and u.hasKey(property)

proc getUnsignedProperty*(event: Event; property: string): Option[JsonNode] =
  ## Get a specific property from unsigned data.
  if event.unsigned.isNone:
    return none(JsonNode)
  let u = event.unsigned.get()
  if u.kind == JObject and u.hasKey(property):
    some(u[property])
  else:
    none(JsonNode)

proc isRedacted*(event: Event): bool =
  ## Check if this event has been redacted.
  if event.unsigned.isNone:
    return false
  let u = event.unsigned.get()
  u.kind == JObject and u.hasKey("redacted_because")

proc redactsId*(event: Event; roomVersion: RoomVersionId): Option[EventId] =
  ## Get the event ID being redacted, if this is a redaction event.
  if event.eventType != "m.room.redaction":
    return none(EventId)
  # For room versions v1-v10, redacts is a top-level property
  case roomVersion
  of "1", "2", "3", "4", "5", "6", "7", "8", "9", "10":
    event.redacts
  else:
    # For v11+, redacts is in the content
    let content = event.getContentAsValue()
    if content.kind == JObject and content.hasKey("redacts"):
      let r = content["redacts"]
      if r.kind == JString:
        some(r.getStr())
      else:
        none(EventId)
    else:
      event.redacts

# ---------------------------------------------------------------------------
# JSON serialization
# ---------------------------------------------------------------------------

proc toJson*(event: Event): JsonNode =
  ## Serialize an Event to a JSON object.
  result = %*{
    "event_id": event.eventId,
    "room_id": event.roomId,
    "sender": event.sender,
    "type": event.eventType,
    "content": event.getContentAsValue(),
    "origin_server_ts": event.originServerTs,
    "depth": event.depth,
  }
  if event.stateKey.isSome:
    result["state_key"] = %event.stateKey.get()
  if event.unsigned.isSome:
    result["unsigned"] = event.unsigned.get()
  if event.prevEvents.len > 0:
    result["prev_events"] = %event.prevEvents
  if event.authEvents.len > 0:
    result["auth_events"] = %event.authEvents
  if event.redacts.isSome:
    result["redacts"] = %event.redacts.get()

proc fromJson*(j: JsonNode): Event =
  ## Deserialize an Event from a JSON object.
  result = Event(
    eventId: j.getOrDefault("event_id").getStr(""),
    roomId: j.getOrDefault("room_id").getStr(""),
    sender: j.getOrDefault("sender").getStr(""),
    eventType: j.getOrDefault("type").getStr(""),
    content: j.getOrDefault("content"),
    originServerTs: j.getOrDefault("origin_server_ts").getBiggestInt(0),
    depth: j.getOrDefault("depth").getBiggestInt(0),
    rejected: false,
  )
  if j.hasKey("state_key"):
    result.stateKey = some(j["state_key"].getStr(""))
  if j.hasKey("unsigned") and j["unsigned"].kind == JObject:
    result.unsigned = some(j["unsigned"])
  if j.hasKey("prev_events") and j["prev_events"].kind == JArray:
    for e in j["prev_events"]:
      result.prevEvents.add(e.getStr())
  if j.hasKey("auth_events") and j["auth_events"].kind == JArray:
    for e in j["auth_events"]:
      result.authEvents.add(e.getStr())
  if j.hasKey("redacts"):
    result.redacts = some(j["redacts"].getStr(""))

# ---------------------------------------------------------------------------
# Sync format conversions — ported from Rust format.rs
# ---------------------------------------------------------------------------

proc toSyncFormat*(event: Event): JsonNode =
  ## Convert to sync (client-facing) format — omits room_id.
  result = %*{
    "event_id": event.eventId,
    "sender": event.sender,
    "type": event.eventType,
    "content": event.getContentAsValue(),
    "origin_server_ts": event.originServerTs,
  }
  if event.stateKey.isSome:
    result["state_key"] = %event.stateKey.get()
  if event.unsigned.isSome:
    result["unsigned"] = event.unsigned.get()
  if event.redacts.isSome:
    result["redacts"] = %event.redacts.get()

proc toTimelineFormat*(event: Event): JsonNode =
  ## Convert to full timeline format — includes room_id.
  result = event.toSyncFormat()
  result["room_id"] = %event.roomId

proc toStrippedFormat*(event: Event): JsonNode =
  ## Convert to stripped state format — minimal fields.
  result = %*{
    "sender": event.sender,
    "type": event.eventType,
    "content": event.getContentAsValue(),
  }
  if event.stateKey.isSome:
    result["state_key"] = %event.stateKey.get()

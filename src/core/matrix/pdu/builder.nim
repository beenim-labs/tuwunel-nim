## PDU Builder — construct PDU events for database insertion.
##
## Ported from Rust core/matrix/pdu/builder.rs — provides the PduBuilder
## type for constructing new Matrix events (both state and timeline).

import std/[json, options, tables]
import ../event

const
  RustPath* = "core/matrix/pdu/builder.rs"
  RustCrate* = "core"

type
  ## Builder for creating new PDU events.
  PduBuilder* = object
    eventType*: TimelineEventType
    content*: JsonNode
    unsigned*: Option[OrderedTable[string, JsonNode]]
    stateKey*: Option[string]
    redacts*: Option[EventId]
    timestamp*: Option[MilliSecondsSinceUnixEpoch]

proc newPduBuilder*(): PduBuilder =
  ## Create a default PduBuilder (m.room.message type).
  PduBuilder(
    eventType: "m.room.message",
    content: newJObject(),
    unsigned: none(OrderedTable[string, JsonNode]),
    stateKey: none(string),
    redacts: none(EventId),
    timestamp: none(MilliSecondsSinceUnixEpoch),
  )

proc stateEvent*(stateKey: string; eventType: string;
                 content: JsonNode): PduBuilder =
  ## Create a PduBuilder for a state event.
  PduBuilder(
    eventType: eventType,
    content: content,
    unsigned: none(OrderedTable[string, JsonNode]),
    stateKey: some(stateKey),
    redacts: none(EventId),
    timestamp: none(MilliSecondsSinceUnixEpoch),
  )

proc timelineEvent*(eventType: string; content: JsonNode): PduBuilder =
  ## Create a PduBuilder for a timeline (message-like) event.
  PduBuilder(
    eventType: eventType,
    content: content,
    unsigned: none(OrderedTable[string, JsonNode]),
    stateKey: none(string),
    redacts: none(EventId),
    timestamp: none(MilliSecondsSinceUnixEpoch),
  )

proc toJson*(builder: PduBuilder): JsonNode =
  ## Serialize the builder to a JSON representation.
  result = %*{
    "type": builder.eventType,
    "content": builder.content,
  }
  if builder.stateKey.isSome:
    result["state_key"] = %builder.stateKey.get()
  if builder.redacts.isSome:
    result["redacts"] = %builder.redacts.get()
  if builder.timestamp.isSome:
    result["origin_server_ts"] = %builder.timestamp.get()
  if builder.unsigned.isSome:
    let u = newJObject()
    for k, v in builder.unsigned.get():
      u[k] = v
    result["unsigned"] = u

proc `$`*(builder: PduBuilder): string =
  ## Debug representation of a PduBuilder.
  result = "PduBuilder(type=" & builder.eventType
  if builder.stateKey.isSome:
    result &= ", state_key=" & builder.stateKey.get()
  if builder.redacts.isSome:
    result &= ", redacts=" & builder.redacts.get()
  if builder.timestamp.isSome:
    result &= ", ts=" & $builder.timestamp.get()
  result &= ", content=" & $builder.content
  result &= ")"

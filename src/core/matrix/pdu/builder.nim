const
  RustPath* = "core/matrix/pdu/builder.rs"
  RustCrate* = "core"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/[json, options]

type
  PduBuilder* = object
    eventType*: string
    content*: JsonNode
    unsigned*: JsonNode
    stateKey*: Option[string]
    redacts*: string
    timestamp*: Option[int64]

proc defaultBuilder*(): PduBuilder =
  PduBuilder(eventType: "m.room.message", content: newJObject(), unsigned: newJObject())

proc stateBuilder*(eventType, stateKey: string; content: JsonNode): PduBuilder =
  result = defaultBuilder()
  result.eventType = eventType
  result.stateKey = some(stateKey)
  result.content = if content.isNil: newJObject() else: content.copy()

proc timelineBuilder*(eventType: string; content: JsonNode): PduBuilder =
  result = defaultBuilder()
  result.eventType = eventType
  result.content = if content.isNil: newJObject() else: content.copy()

proc withUnsigned*(builder: PduBuilder; unsigned: JsonNode): PduBuilder =
  result = builder
  result.unsigned = if unsigned.isNil: newJObject() else: unsigned.copy()

proc withRedacts*(builder: PduBuilder; eventId: string): PduBuilder =
  result = builder
  result.redacts = eventId

proc withTimestamp*(builder: PduBuilder; timestamp: int64): PduBuilder =
  result = builder
  result.timestamp = some(timestamp)

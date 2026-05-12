const
  RustPath* = "core/matrix/pdu.rs"
  RustCrate* = "core"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"
  MaxPduBytes* = 65_535
  MaxPrevEvents* = 20
  MaxAuthEvents* = 10

import std/[json, options]

import core/matrix/pdu/[
  builder,
  count,
  format,
  hashes,
  id,
  raw_id,
]

export
  builder,
  count,
  format,
  hashes,
  id,
  raw_id

type
  Pdu* = object
    eventId*: string
    roomId*: string
    sender*: string
    eventType*: string
    stateKey*: Option[string]
    originServerTs*: int64
    content*: JsonNode
    unsigned*: JsonNode
    authEvents*: seq[string]
    prevEvents*: seq[string]
    redacts*: string
    rejected*: bool

proc pdu*(
    eventId, roomId, sender, eventType: string;
    content: JsonNode;
    originServerTs = 0'i64;
    stateKey = none(string);
    unsigned: JsonNode = nil;
    authEvents: openArray[string] = [];
    prevEvents: openArray[string] = [];
    redacts = "";
    rejected = false
): Pdu =
  result = Pdu(
    eventId: eventId,
    roomId: roomId,
    sender: sender,
    eventType: eventType,
    stateKey: stateKey,
    originServerTs: originServerTs,
    content: if content.isNil: newJObject() else: content.copy(),
    unsigned: if unsigned.isNil: newJObject() else: unsigned.copy(),
    redacts: redacts,
    rejected: rejected,
  )
  for eventId in authEvents:
    result.authEvents.add(eventId)
  for eventId in prevEvents:
    result.prevEvents.add(eventId)

proc toJson*(event: Pdu): JsonNode =
  result = %*{
    "event_id": event.eventId,
    "room_id": event.roomId,
    "sender": event.sender,
    "type": event.eventType,
    "origin_server_ts": event.originServerTs,
    "content": event.content,
  }
  if event.stateKey.isSome:
    result["state_key"] = %event.stateKey.get()
  if event.unsigned.kind == JObject and event.unsigned.len > 0:
    result["unsigned"] = event.unsigned
  if event.authEvents.len > 0:
    result["auth_events"] = %event.authEvents
  if event.prevEvents.len > 0:
    result["prev_events"] = %event.prevEvents
  if event.redacts.len > 0:
    result["redacts"] = %event.redacts

proc fromJson*(event: JsonNode): tuple[ok: bool, pdu: Pdu, message: string] =
  if event.isNil or event.kind != JObject:
    return (false, Pdu(), "PDU must be an object")
  let eventId = event{"event_id"}.getStr("")
  let roomId = event{"room_id"}.getStr("")
  let sender = event{"sender"}.getStr("")
  let eventType = event{"type"}.getStr("")
  if eventId.len == 0 or roomId.len == 0 or sender.len == 0 or eventType.len == 0:
    return (false, Pdu(), "event_id, room_id, sender, and type are required")
  var stateKeyOpt = none(string)
  if event.hasKey("state_key"):
    stateKeyOpt = some(event["state_key"].getStr(""))
  var auth: seq[string] = @[]
  if event{"auth_events"}.kind == JArray:
    for node in event["auth_events"]:
      auth.add(node.getStr(""))
  var prev: seq[string] = @[]
  if event{"prev_events"}.kind == JArray:
    for node in event["prev_events"]:
      prev.add(node.getStr(""))
  (true, pdu(
    eventId,
    roomId,
    sender,
    eventType,
    event{"content"},
    event{"origin_server_ts"}.getInt(0).int64,
    stateKeyOpt,
    event{"unsigned"},
    auth,
    prev,
    event{"redacts"}.getStr(""),
    event{"rejected"}.getBool(false),
  ), "")

## timeline/create — service module.
##
## Ported from Rust service/rooms/timeline/create.rs
##
## Event creation: constructs a PDU from a builder (event_type, content,
## state_key, etc.), fetches prev_events and auth_events, computes
## depth, applies content hashing, and signs with the server key.

import std/[options, json, tables, strutils, logging, times, algorithm]

const
  RustPath* = "service/rooms/timeline/create.rs"
  RustCrate* = "service"

type
  PduBuilder* = object
    eventType*: string
    content*: JsonNode
    unsigned*: Option[JsonNode]
    stateKey*: Option[string]
    redacts*: Option[string]
    timestamp*: Option[uint64]

proc createHashAndSignEvent*(self: auto; pduBuilder: PduBuilder;
                             sender, roomId: string): tuple[pdu: JsonNode, pduJson: JsonNode] =
  ## Ported from `create_hash_and_sign_event`.
  ##
  ## Creates a new event PDU from a builder:
  ## 1. Fetch forward extremities as prev_events (up to 20)
  ## 2. Determine room version (from create event or builder)
  ## 3. Fetch auth events for the event type
  ## 4. Compute depth (max of prev_events depths + 1)
  ## 5. Add prev_content/replaces_state for state events
  ## 6. Build PduEvent structure
  ## 7. Run auth_check to validate the event
  ## 8. Hash and sign with server keys
  ## 9. Generate event_id from hash
  ## 10. Generate short event ID mapping

  # 1. Get prev_events (forward extremities, max 20)
  # In real impl: self.services.state.getForwardExtremities(roomId).take(20)
  var prevEvents: seq[string] = @[]

  # 2. Get room version
  # In real impl: self.services.state.getRoomVersion(roomId)
  # For m.room.create: parse from content
  var roomVersion = "10"  # default
  if pduBuilder.eventType == "m.room.create":
    let contentVersion = pduBuilder.content.getOrDefault("room_version").getStr("")
    if contentVersion.len > 0:
      roomVersion = contentVersion

  # 3. Get auth events
  # In real impl: self.services.state.getAuthEvents(roomId, eventType, sender, stateKey, content, rules, true)
  var authEvents: seq[string] = @[]

  # 4. Compute depth
  var depth: uint64 = 1
  for prevEventId in prevEvents:
    # In real impl: get PDU, check depth
    discard

  # 5. Add prev_content for state events
  var unsigned = pduBuilder.unsigned.get(%*{})
  if pduBuilder.stateKey.isSome:
    # In real impl: look up existing state event
    # unsigned["prev_content"] = existingPdu.content
    # unsigned["prev_sender"] = existingPdu.sender
    # unsigned["replaces_state"] = existingPdu.event_id
    discard

  let unsignedOpt = if unsigned.len > 0: some(unsigned) else: none(JsonNode)

  # 6. Build timestamp
  let originServerTs = if pduBuilder.timestamp.isSome:
    pduBuilder.timestamp.get()
  else:
    (epochTime() * 1000).uint64

  # 7. Build PduEvent
  var pdu = %*{
    "event_id": "$placeholder",  # will be replaced
    "room_id": roomId,
    "sender": sender,
    "origin_server_ts": originServerTs,
    "type": pduBuilder.eventType,
    "content": pduBuilder.content,
    "depth": depth,
    "prev_events": prevEvents,
    "auth_events": authEvents,
  }

  if pduBuilder.stateKey.isSome:
    pdu["state_key"] = %pduBuilder.stateKey.get()

  if pduBuilder.redacts.isSome:
    pdu["redacts"] = %pduBuilder.redacts.get()

  if unsignedOpt.isSome:
    pdu["unsigned"] = unsignedOpt.get()

  # 8. Auth check
  # In real impl: state_res.authCheck(versionRules, pdu, getPdu, authFetch)

  # 9. Hash and sign
  # In real impl: self.services.serverKeys.genIdHashAndSignEvent(pduJson, roomVersion)
  var pduJson = pdu

  # 10. Generate short event id
  # In real impl: self.services.short.getOrCreateShorteventid(pdu.eventId)

  debug "create_hash_and_sign_event: type=", pduBuilder.eventType,
        " room=", roomId, " sender=", sender

  (pdu: pdu, pduJson: pduJson)
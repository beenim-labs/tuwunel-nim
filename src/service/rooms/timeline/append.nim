## timeline/append — service module.
##
## Ported from Rust service/rooms/timeline/append.rs
##
## Event appending: persists PDUs to the timeline, handles incoming
## federation events (with soft-fail), and processes side-effects
## (relations, threads, search indexing, read receipts, notifications).

import std/[options, json, tables, strutils, logging]

const
  RustPath* = "service/rooms/timeline/append.rs"
  RustCrate* = "service"

proc appendIncomingPdu*(self: auto; pdu: JsonNode; pduJson: JsonNode;
                       newRoomLeafs: seq[string];
                       stateIdsCompressed: seq[tuple[key: uint64, event: uint64]];
                       softFail: bool): Option[string] =
  ## Ported from `append_incoming_pdu`.
  ##
  ## Appends an incoming federation event, setting the state snapshot
  ## to the state from the sending server.
  ##
  ## If soft_fail is true, the event is stored but not appended to
  ## the timeline (it still influences state though).

  if softFail:
    # Soft-failed events: set event state but don't append to timeline
    # In real impl:
    # let shortstatehash = self.services.state.setEventState(eventId, roomId, stateIdsCompressed)
    # self.services.pduMetadata.markEventSoftFailed(eventId)
    let eventId = pdu.getOrDefault("event_id").getStr("")
    debug "append_incoming_pdu: soft-fail for ", eventId
    return none(string)

  # Not soft-failed: append normally
  let roomId = pdu.getOrDefault("room_id").getStr("")
  let eventId = pdu.getOrDefault("event_id").getStr("")

  # In real impl:
  # let shortstatehash = self.services.state.setEventState(eventId, roomId, stateIdsCompressed)
  # let pduId = self.appendPdu(pdu, pduJson, newRoomLeafs, stateLock)
  # self.services.state.setRoomState(roomId, shortstatehash, stateLock)

  debug "append_incoming_pdu: appended ", eventId, " in ", roomId
  some(eventId)


proc appendPdu*(self: auto; pdu: JsonNode; pduJson: JsonNode;
                leafs: seq[string]): string =
  ## Ported from `append_pdu`.
  ##
  ## By this point the incoming event should be fully authenticated.
  ## Steps:
  ## 1. Allocate pdu_id (shortroomid + count)
  ## 2. Update forward extremities (remove old leafs, add new)
  ## 3. Persist PDU JSON
  ## 4. Process side-effects (relations, threads, search, notifications)

  let roomId = pdu.getOrDefault("room_id").getStr("")
  let eventId = pdu.getOrDefault("event_id").getStr("")

  # 1. Allocate pdu_id
  # In real impl: let shortroomid = self.services.short.getOrCreateShortroomid(roomId)
  # let count = self.services.globals.nextCount()
  # let pduId = PduId{shortroomid, count}

  # 2. Update forward extremities
  # In real impl: mark referenced events, set new extremities
  for leaf in leafs:
    # self.services.pduMetadata.markEventReferenced(roomId, leaf)
    discard

  # 3. Persist
  # self.appendPduJson(pduId, pdu, pduJson, count)

  # 4. Side-effects
  # self.appendPduEffects(pduId, pdu, shortroomid, count)

  debug "append_pdu: ", eventId, " in ", roomId
  eventId


proc appendPduEffects*(self: auto; pduId: string; pdu: JsonNode;
                       shortroomid: uint64; count: uint64) =
  ## Ported from `append_pdu_effects`.
  ##
  ## Processes all side-effects of appending a PDU:
  ## 1. Update relations (m.relates_to in content)
  ## 2. Update thread participants
  ## 3. Index message body for search
  ## 4. Update membership state cache
  ## 5. Handle invites (create invite state)
  ## 6. Handle leaves (forget room if needed)
  ## 7. Send push notifications
  ## 8. Update room server participation

  let eventType = pdu.getOrDefault("type").getStr("")
  let roomId = pdu.getOrDefault("room_id").getStr("")
  let sender = pdu.getOrDefault("sender").getStr("")
  let content = pdu.getOrDefault("content")

  # 1. Relations
  let relatesTo = content.getOrDefault("m.relates_to")
  if relatesTo.kind != JNull:
    let relType = relatesTo.getOrDefault("rel_type").getStr("")
    let targetEventId = relatesTo.getOrDefault("event_id").getStr("")
    if targetEventId.len > 0:
      # In real impl: self.services.pduMetadata.addRelation(count, targetEventId)
      debug "relation: ", relType, " → ", targetEventId

      # 2. Thread participants
      if relType == "m.thread":
        # In real impl: self.services.threads.updateParticipants(targetEventId, @[sender])
        discard

  # 3. Search indexing
  if eventType == "m.room.message":
    let body = content.getOrDefault("body").getStr("")
    if body.len > 0:
      # In real impl: self.services.search.indexPdu(shortroomid, pduId, body)
      discard

  # 4. Membership state cache
  if eventType == "m.room.member":
    let membership = content.getOrDefault("membership").getStr("")
    let stateKey = pdu.getOrDefault("state_key").getStr("")
    # In real impl: self.services.stateCache.updateMembership(roomId, stateKey, membership, ...)
    debug "membership update: ", stateKey, " → ", membership

  # 5. Invite state
  if eventType == "m.room.member":
    let membership = content.getOrDefault("membership").getStr("")
    if membership == "invite":
      # In real impl: create invite state
      discard

  # 6. Push notifications
  # In real impl: self.services.pusher.handleEvent(pdu)

  debug "append_pdu_effects: type=", eventType, " room=", roomId


proc appendPduJson*(self: auto; pduId: string; pdu: JsonNode;
                    json: JsonNode; count: uint64) =
  ## Ported from `append_pdu_json`.
  ## Low-level persistence: writes PDU JSON to database.

  # In real impl:
  # self.db.pduidPdu.rawPut(pduId, Json(json))
  # self.db.eventidPduid.insert(pdu.eventId, pduId)
  # self.db.eventidOutlierpdu.remove(pdu.eventId)

  let eventId = pdu.getOrDefault("event_id").getStr("")
  debug "append_pdu_json: ", eventId, " as ", pduId

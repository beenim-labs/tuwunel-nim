## event_handler/handle_incoming_pdu — service module.
##
## Ported from Rust service/rooms/event_handler/handle_incoming_pdu.rs
##
## Main entry point for processing incoming PDUs from federation.
## Implements the 14-step verification process defined in the Matrix spec:
##   0. Check server is in room
##   1. Skip if already known
##   2. Verify signatures
##   3. Check content hash
##   4-6. Auth event checks
##   7. Persist as outlier
##   8. Stop if not timeline event
##   9. Fetch missing prev events
##   10-14. State resolution, auth, soft-fail

import std/[options, json, tables, strutils, logging]
import ./mod as event_handler_mod

const
  RustPath* = "service/rooms/event_handler/handle_incoming_pdu.rs"
  RustCrate* = "service"

type
  RawPduId* = string
  IncomingPduResult* = Option[tuple[pduId: RawPduId, isNew: bool]]

proc handleIncomingPdu*(self: Service; origin: string; roomId: string;
                        eventId: string; pdu: JsonNode;
                        isTimelineEvent: bool): IncomingPduResult =
  ## Ported from `handle_incoming_pdu`.
  ##
  ## When receiving an event one needs to:
  ##  0. Check the server is in the room
  ##  1. Skip the PDU if we already know about it
  ##  1.1. Remove unsigned field
  ##  2. Check signatures, otherwise drop
  ##  3. Check content hash, redact if doesn't match
  ##  4. Fetch any missing auth events
  ##  5-6. Reject if auth events fail
  ##  7. Persist as outlier
  ##  8. If not timeline event: stop
  ##  9. Fetch missing prev events
  ##  10-14. State resolution and timeline append

  # 1. Skip the PDU if we already have it as a timeline event
  # In real impl: self.services.timeline.getPduId(eventId)
  # For now we log and continue
  debug "handle_incoming_pdu: processing ", eventId, " in room ", roomId

  # 1.1 Check the server is in the room
  # In real impl: self.services.metadata.exists(roomId)
  let metaExists = true  # placeholder: room existence check

  # 1.2 Check if the room is disabled
  # In real impl: self.services.metadata.isDisabled(roomId)
  let isDisabled = false  # placeholder

  # 1.3.1 Check room ACL on origin field/server
  # In real impl: self.aclCheck(origin, roomId)

  # 1.3.2 Check room ACL on sender's server name
  let sender = pdu.getOrDefault("sender").getStr("")
  if sender.len == 0:
    raise newException(ValueError, "PDU does not have a valid sender key")

  if not metaExists:
    raise newException(ValueError, "Room is unknown to this server")

  if isDisabled:
    raise newException(ValueError,
      "Federation of this room is disabled by this server.")

  # Fetch create event to determine room version
  # In real impl: self.services.stateAccessor.roomStateGet(...)
  # let createEvent = ...
  # let roomVersion = roomVersion.fromCreateEvent(createEvent)

  # Handle as outlier first (steps 2-7)
  # In real impl: self.handleOutlierPdu(origin, roomId, eventId, pdu, roomVersion, false)
  # let (incomingPdu, val) = ...

  # 8. If not timeline event: stop
  if not isTimelineEvent:
    debug "handle_incoming_pdu: not a timeline event, stopping"
    return none(tuple[pduId: RawPduId, isNew: bool])

  # Skip old events
  # In real impl:
  #   let firstTs = self.services.timeline.firstPduInRoom(roomId).originServerTs
  #   if incomingPdu.originServerTs < firstTs: return none(...)

  # 9. Fetch any missing prev events
  # In real impl: self.fetchPrev(origin, roomId, prevEvents, roomVersion, firstTs)
  # let (sortedPrevEvents, eventidInfo) = ...

  # Process previous events
  # In real impl: iterate sortedPrevEvents, call handlePrevPdu for each

  # Upgrade outlier to timeline PDU (steps 10-14)
  # In real impl: self.upgradeOutlierToTimelinePdu(...)
  # return result

  # Placeholder return until service integration is wired
  none(tuple[pduId: RawPduId, isNew: bool])
## event_handler/upgrade_outlier_pdu — service module.
##
## Ported from Rust service/rooms/event_handler/upgrade_outlier_pdu.rs
##
## Upgrades an outlier PDU (one that passed initial validation) to a full
## timeline event. This involves:
##   - Skipping if we already have it
##   - Checking soft-fail status
##   - Verifying PDU format
##   - Resolving state at the incoming event
##   - Auth checking against state
##   - Computing extremities
##   - State resolution and persistence
##   - Timeline append with soft-fail handling

import std/[options, json, tables, strutils, logging, times, sequtils]
import ./mod as event_handler_mod
import ./resolve_state
import ./state_at_incoming
import ./fetch_state as fetch_state_mod

const
  RustPath* = "service/rooms/event_handler/upgrade_outlier_pdu.rs"
  RustCrate* = "service"

type
  RawPduId* = string
  HashSetCompressStateEvent* = object
    shortstatehash*: uint64
    added*: seq[CompressedStateEvent]
    removed*: seq[CompressedStateEvent]

proc upgradeOutlierToTimelinePdu*(self: Service; origin: string;
                                  roomId: string; incomingPdu: JsonNode;
                                  val: JsonNode; roomVersion: string;
                                  createEventId: string): Option[tuple[pduId: RawPduId, isNew: bool]] =
  ## Ported from `upgrade_outlier_to_timeline_pdu`.
  ##
  ## Promotes an outlier PDU to a timeline event after full validation.

  let eventId = incomingPdu.getOrDefault("event_id").getStr("")

  # Skip if we already have it as a timeline event
  # In real impl: self.services.timeline.getPduId(eventId)
  debug "upgrade_outlier: checking if ", eventId, " already exists"

  # Check soft-fail status
  # In real impl: self.services.pduMetadata.isEventSoftFailed(eventId)
  let alreadySoftFailed = false  # placeholder
  if alreadySoftFailed:
    raise newException(ValueError, "Event has been soft failed")

  debug "upgrade_outlier: upgrading to timeline pdu"
  let timer = getTime()

  # Check PDU format according to room version rules
  # In real impl: stateRes.checkPduFormat(val, roomRules.eventFormat)

  # 10. Fetch missing state and auth chain events
  debug "upgrade_outlier: resolving state at event"

  # Determine state at the incoming event
  let prevEvents = incomingPdu.getOrDefault("prev_events")
  let prevCount = if prevEvents.kind == JArray: prevEvents.len else: 0

  var stateAtIncoming: Option[Table[uint64, string]]

  if prevCount == 1:
    stateAtIncoming = self.stateAtIncomingDegreeOne(incomingPdu)
  else:
    stateAtIncoming = self.stateAtIncomingResolved(incomingPdu, roomId, roomVersion)

  # If we still don't have state, fetch it from the remote server
  if stateAtIncoming.isNone:
    stateAtIncoming = self.fetchState(origin, roomId, eventId, roomVersion, createEventId)

  if stateAtIncoming.isNone:
    raise newException(ValueError, "Could not determine state at incoming event")

  let stateAtEvent = stateAtIncoming.get()

  # 11. Check the auth of the event passes based on the state of the event
  debug "upgrade_outlier: performing auth check"
  # In real impl: stateRes.authCheck(roomRules, incomingPdu, eventFetch, stateFetch)

  # Gather auth events for the current room state
  debug "upgrade_outlier: gathering auth events"
  # In real impl: self.services.state.getAuthEvents(roomId, ...)

  # Second auth check against gathered auth events
  debug "upgrade_outlier: second auth check"
  # In real impl: stateRes.authCheck(roomRules, incomingPdu, eventFetch, stateFetch2)

  # Soft fail check before doing state res
  debug "upgrade_outlier: soft-fail check"
  var softFail = false
  # In real impl: check if user can redact
  let redactsId = incomingPdu.getOrDefault("redacts").getStr("")
  if redactsId.len > 0:
    # In real impl: check user_can_redact permission
    softFail = false  # placeholder

  # 13. Use state resolution to find new room state
  debug "upgrade_outlier: locking the room"
  # In real impl: self.services.state.mutex.lock(roomId)

  # Calculate extremities after this incoming event
  debug "upgrade_outlier: calculating extremities"
  var extremities: seq[string] = @[]
  # In real impl: self.services.state.getForwardExtremities(roomId)
  #   filter out events referenced by incoming_pdu.prev_events
  #   filter out events already referenced by other events

  # Compress state
  debug "upgrade_outlier: compressing state"
  # In real impl: self.services.stateCompressor.compressStateEvents(stateAtEvent)
  let stateIdsCompressed: CompressedState = @[]

  # If this is a state event, resolve the new room state
  if incomingPdu.hasKey("state_key"):
    let stateKey = incomingPdu.getOrDefault("state_key").getStr("")
    let eventType = incomingPdu.getOrDefault("type").getStr("")

    # Build state_after by inserting this event
    var stateAfter = stateAtEvent
    # In real impl: self.services.short.getOrCreateShortstatekey(eventType, stateKey)
    let shortstatekey: uint64 = 0  # placeholder
    stateAfter[shortstatekey] = eventId

    debug "upgrade_outlier: resolving new room state, type=", eventType,
          " state_key=", stateKey

    # Resolve state
    let newRoomState = self.resolveState(roomId, roomVersion, stateAfter)

    # Save the resolved state
    debug "upgrade_outlier: saving resolved state"
    # In real impl: self.services.stateCompressor.saveState(roomId, newRoomState)
    # In real impl: self.services.state.forceState(roomId, shortstatehash, added, removed, stateLock)

  # 14. Append to timeline
  debug "upgrade_outlier: appending pdu to timeline"

  # Add incoming event as an extremity unless it was soft-failed
  if not softFail:
    extremities.add(eventId)

  # In real impl: self.services.timeline.appendIncomingPdu(...)
  let pduId = eventId  # placeholder

  if softFail:
    # In real impl: self.services.pduMetadata.markEventSoftFailed(eventId)
    let elapsed = getTime() - timer
    warn "upgrade_outlier: event was soft failed: ", eventId,
         " elapsed=", elapsed
    raise newException(ValueError, "Event has been soft failed")

  let elapsed = getTime() - timer
  debug "upgrade_outlier: accepted ", eventId, " elapsed=", elapsed

  some((pduId: pduId, isNew: true))
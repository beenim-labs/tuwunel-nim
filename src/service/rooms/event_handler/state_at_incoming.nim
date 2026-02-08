## event_handler/state_at_incoming — service module.
##
## Ported from Rust service/rooms/event_handler/state_at_incoming.rs
##
## Determines the room state at the point of an incoming event by examining
## its prev_events. Two code paths: degree-one (single prev_event, fast path)
## and multi-prev (state resolution required).

import std/[options, json, tables, strutils, logging, sequtils]
import ./mod as event_handler_mod
import ./resolve_state

const
  RustPath* = "service/rooms/event_handler/state_at_incoming.rs"
  RustCrate* = "service"

type
  ShortStateHash* = uint64

proc stateAtIncomingDegreeOne*(self: Service;
                               incomingPdu: JsonNode): Option[Table[uint64, string]] =
  ## Ported from `state_at_incoming_degree_one`.
  ##
  ## Fast path for when the incoming PDU has exactly one prev_event.
  ## Looks up the state at the prev_event and optionally adds the prev_event
  ## itself if it's a state event.

  let prevEvents = incomingPdu.getOrDefault("prev_events")
  if prevEvents.kind != JArray or prevEvents.len != 1:
    debug "state_at_incoming_degree_one: expected exactly 1 prev_event"
    return none(Table[uint64, string])

  let prevEventId = prevEvents[0].getStr("")

  # Look up the state hash at this prev event
  # In real impl: self.services.state.pduShortstatehash(prevEventId)
  let prevEventSstatehash: Option[ShortStateHash] = none(ShortStateHash)  # placeholder

  if prevEventSstatehash.isNone:
    debug "state_at_incoming_degree_one: missing state at prev_event ", prevEventId
    return none(Table[uint64, string])

  let sstatehash = prevEventSstatehash.get()
  debug "state_at_incoming_degree_one: resolving state at ", prevEventId,
        " hash=", sstatehash

  # Fetch the prev event itself
  # In real impl: self.services.timeline.getPdu(prevEventId)
  let prevEvent = none(JsonNode)  # placeholder
  if prevEvent.isNone:
    raise newException(ValueError,
      "Could not find prev_event, but we know the state")

  # Load the full state at prev_event
  # In real impl: self.services.stateAccessor.stateFullIds(sstatehash)
  var state = initTable[uint64, string]()

  # If the prev_event is a state event, add it to the state
  let pe = prevEvent.get()
  if pe.hasKey("state_key"):
    let stateKey = pe.getOrDefault("state_key").getStr("")
    let eventType = pe.getOrDefault("type").getStr("")
    let peEventId = pe.getOrDefault("event_id").getStr("")

    # In real impl: self.services.short.getOrCreateShortstatekey(eventType, stateKey)
    let shortstatekey: uint64 = 0  # placeholder

    state[shortstatekey] = peEventId
    debug "state_at_incoming_degree_one: added prev_event to state, ",
          "type=", eventType, " state_key=", stateKey

  if state.len == 0:
    return none(Table[uint64, string])

  some(state)


proc stateAtIncomingResolved*(self: Service; incomingPdu: JsonNode;
                              roomId: string;
                              roomVersion: string): Option[Table[uint64, string]] =
  ## Ported from `state_at_incoming_resolved`.
  ##
  ## Handles the case where the incoming PDU has multiple prev_events.
  ## Resolves state across all prev_events using the state resolution algorithm.

  let prevEvents = incomingPdu.getOrDefault("prev_events")
  if prevEvents.kind != JArray or prevEvents.len <= 1:
    debug "state_at_incoming_resolved: expected > 1 prev_event"
    return none(Table[uint64, string])

  debug "state_at_incoming_resolved: calculating extremity statehashes"

  # For each prev_event, get its state hash and the event itself
  type ExtremityInfo = tuple[sstatehash: ShortStateHash, prevEvent: JsonNode]
  var extremities: Table[ShortStateHash, JsonNode] = initTable[ShortStateHash, JsonNode]()

  for pe in prevEvents:
    let peId = pe.getStr("")
    # In real impl: self.services.state.pduShortstatehash(peId)
    let sstatehash: Option[ShortStateHash] = none(ShortStateHash)  # placeholder
    # In real impl: self.services.timeline.getPdu(peId)
    let prevEvent = none(JsonNode)  # placeholder

    if sstatehash.isNone or prevEvent.isNone:
      debug "state_at_incoming_resolved: missing state at prev_event ", peId
      return none(Table[uint64, string])

    extremities[sstatehash.get()] = prevEvent.get()

  debug "state_at_incoming_resolved: calculating fork states"

  # For each extremity, compute the fork state and auth chain
  var forkStates: seq[StateMap] = @[]
  var authChainSets: seq[AuthSet] = @[]

  for (sstatehash, prevEvent) in extremities.pairs:
    # In real impl: self.stateAtIncomingFork(roomId, roomVersion, sstatehash, prevEvent)
    var stateMap: StateMap = initTable[tuple[eventType: string, stateKey: string], string]()
    var authSet: AuthSet = @[]
    forkStates.add(stateMap)
    authChainSets.add(authSet)

  debug "state_at_incoming_resolved: resolving state"

  # Run state resolution
  let resolvedState = self.stateResolution(roomId, roomVersion, forkStates, authChainSets)

  # Convert back to shortstatekey → event_id mapping
  var result = initTable[uint64, string]()
  for ((eventType, stateKey), eventId) in resolvedState.pairs:
    # In real impl: self.services.short.getOrCreateShortstatekey(eventType, stateKey)
    let shortstatekey: uint64 = 0  # placeholder
    result[shortstatekey] = eventId

  debug "state_at_incoming_resolved: created ", result.len, " shortstatekeys"
  some(result)
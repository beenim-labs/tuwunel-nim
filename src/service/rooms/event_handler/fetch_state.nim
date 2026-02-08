## event_handler/fetch_state — service module.
##
## Ported from Rust service/rooms/event_handler/fetch_state.rs
##
## Calls /state_ids on a remote server to determine the room state at a
## specific event. Fetches and validates the state events, builds a
## short-state-key → event-id mapping, and verifies the create event
## is still in the resulting state.

import std/[options, json, tables, strutils, logging]
import ./mod as event_handler_mod
import ./fetch_auth

const
  RustPath* = "service/rooms/event_handler/fetch_state.rs"
  RustCrate* = "service"

type
  ShortStateKey* = uint64

proc fetchState*(self: Service; origin: string; roomId: string;
                 eventId: string; roomVersion: string;
                 createEventId: string): Option[Table[ShortStateKey, string]] =
  ## Ported from `fetch_state`.
  ##
  ## Calls /state_ids to find out what the state at this PDU is.
  ## We trust the server's response to some extent, but still perform
  ## extensive checks on the events.

  # Call /state_ids on the origin server
  # In real impl: self.services.federation.execute(origin, getRoomStateIds request)
  debug "fetch_state: fetching state for event ", eventId, " in room ", roomId

  # placeholder: simulate federation response
  # In real impl: let res = federation.execute(...)
  #   if failed: debug_warn("Fetching state for event failed"); return none
  let pduIds: seq[string] = @[]  # placeholder: res.pduIds

  # Fetch and validate state events
  debug "fetch_state: fetching state events"
  let stateVec = self.fetchAuth(origin, roomId, pduIds, roomVersion)

  # Build short-state-key → event-id mapping
  var state = initTable[ShortStateKey, string]()

  for (pdu, _) in stateVec:
    # Each state event must have a state_key
    let stateKey = pdu.getOrDefault("state_key").getStr("")
    if stateKey.len == 0 and not pdu.hasKey("state_key"):
      raise newException(ValueError, "Found non-state PDU in state events")

    let eventType = pdu.getOrDefault("type").getStr("")

    # In real impl: self.services.short.getOrCreateShortstatekey(eventType, stateKey)
    let shortstatekey: ShortStateKey = 0  # placeholder

    # Check for duplicate (type, state_key) combinations
    if shortstatekey in state:
      raise newException(ValueError,
        "State event's type and state_key (" & eventType & "," & stateKey &
        ") exists multiple times")

    let pduEventId = pdu.getOrDefault("event_id").getStr("")
    state[shortstatekey] = pduEventId

  # Verify the original create event is still in the state
  # In real impl: self.services.short.getShortstatekey("m.room.create", "")
  let createShortstatekey: ShortStateKey = 0  # placeholder

  if createShortstatekey in state:
    let createInState = state[createShortstatekey]
    if createInState != createEventId:
      raise newException(ValueError,
        "Incoming event refers to wrong create event")
  else:
    raise newException(ValueError,
      "Incoming event refers to wrong create event")

  some(state)
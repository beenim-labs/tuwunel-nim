const
  RustPath* = "api/client/state.rs"
  RustCrate* = "api"

import std/json

type
  StatePolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc stateEventsResponse*(roomState: JsonNode): JsonNode =
  if roomState.isNil:
    newJArray()
  else:
    roomState.copy()

proc stateEventResponse*(contentOrEvent: JsonNode): JsonNode =
  if contentOrEvent.isNil:
    newJObject()
  else:
    contentOrEvent.copy()

proc sendStateResponse*(eventId: string): JsonNode =
  %*{"event_id": eventId}

proc stateAccessPolicy*(roomExists, canViewState: bool): StatePolicyResult =
  if not roomExists:
    return (false, "M_NOT_FOUND", "Room not found.")
  if not canViewState:
    return (false, "M_FORBIDDEN", "You don't have permission to view the room state.")
  (true, "", "")

proc stateEventPolicy*(roomExists, canViewState, eventExists: bool): StatePolicyResult =
  let access = stateAccessPolicy(roomExists, canViewState)
  if not access.ok:
    return access
  if not eventExists:
    return (false, "M_NOT_FOUND", "State event not found.")
  (true, "", "")

proc sendStatePolicy*(roomExists, canSendState: bool; eventType = ""; encryptionAllowed = true): StatePolicyResult =
  if not roomExists:
    return (false, "M_NOT_FOUND", "Room not found.")
  if not canSendState:
    return (false, "M_FORBIDDEN", "You are not joined to this room.")
  if eventType == "m.room.create":
    return (false, "M_BAD_JSON", "You cannot update m.room.create after a room has been created.")
  if eventType == "m.room.encryption" and not encryptionAllowed:
    return (false, "M_FORBIDDEN", "Encryption is disabled on this homeserver.")
  (true, "", "")

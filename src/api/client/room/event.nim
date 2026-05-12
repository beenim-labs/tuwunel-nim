const
  RustPath* = "api/client/room/event.rs"
  RustCrate* = "api"

import std/json

type
  RoomEventPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc roomEventResponse*(event: JsonNode): JsonNode =
  if event.isNil:
    newJObject()
  else:
    event.copy()

proc roomEventAccessPolicy*(roomExists, canViewRoom, eventExists: bool): RoomEventPolicyResult =
  if not roomExists:
    return (false, "M_NOT_FOUND", "Room not found.")
  if not canViewRoom:
    return (false, "M_FORBIDDEN", "You don't have permission to view this event.")
  if not eventExists:
    return (false, "M_NOT_FOUND", "Event not found.")
  (true, "", "")

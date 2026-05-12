const
  RustPath* = "api/client/membership/join.rs"
  RustCrate* = "api"

import std/json

type
  JoinPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc joinMembership*(): string =
  "join"

proc joinedRoomsResponse*(roomIds: openArray[string]): JsonNode =
  var joinedRooms = newJArray()
  for roomId in roomIds:
    if roomId.len > 0:
      joinedRooms.add(%roomId)
  %*{"joined_rooms": joinedRooms}

proc joinResponse*(roomId: string): JsonNode =
  %*{"room_id": roomId}

proc joinTargetPolicy*(roomExists: bool): JoinPolicyResult =
  if not roomExists:
    return (false, "M_NOT_FOUND", "Room not found.")
  (true, "", "")

const
  RustPath* = "api/client/membership/mod.rs"
  RustCrate* = "api"

import std/json

proc joinedRoomsResponse*(roomIds: openArray[string]): JsonNode =
  var joinedRooms = newJArray()
  for roomId in roomIds:
    if roomId.len > 0:
      joinedRooms.add(%roomId)
  %*{"joined_rooms": joinedRooms}

proc emptyMembershipResponse*(): JsonNode =
  newJObject()

proc isActiveMembership*(membership: string): bool =
  membership in ["join", "invite", "knock"]

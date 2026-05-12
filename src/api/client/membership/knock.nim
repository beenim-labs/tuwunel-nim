const
  RustPath* = "api/client/membership/knock.rs"
  RustCrate* = "api"

import std/json

type
  KnockPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc knockMembership*(): string =
  "knock"

proc knockResponse*(roomId: string): JsonNode =
  %*{"room_id": roomId}

proc knockTargetPolicy*(roomExists: bool): KnockPolicyResult =
  if not roomExists:
    return (false, "M_NOT_FOUND", "Room not found.")
  (true, "", "")

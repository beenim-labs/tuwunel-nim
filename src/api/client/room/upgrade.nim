const
  RustPath* = "api/client/room/upgrade.rs"
  RustCrate* = "api"

import std/json

type
  UpgradePolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc upgradeResponse*(replacementRoom: string): JsonNode =
  %*{"replacement_room": replacementRoom}

proc upgradePolicy*(roomExists, canUpgrade: bool): UpgradePolicyResult =
  if not roomExists:
    return (false, "M_NOT_FOUND", "Room not found.")
  if not canUpgrade:
    return (false, "M_FORBIDDEN", "You are not in the room you are upgrading.")
  (true, "", "")

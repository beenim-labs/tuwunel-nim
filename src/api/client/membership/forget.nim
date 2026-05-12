const
  RustPath* = "api/client/membership/forget.rs"
  RustCrate* = "api"

import std/json

type
  ForgetPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc forgetResponse*(): JsonNode =
  newJObject()

proc forgetPolicy*(roomExists: bool; membership: string; joinedCacheContains = false): ForgetPolicyResult =
  if not roomExists:
    return (false, "M_NOT_FOUND", "Room not found.")
  if membership in ["join", "invite", "knock"] or joinedCacheContains:
    return (false, "M_UNKNOWN", "You must leave the room before forgetting it")
  if membership.len == 0:
    return (false, "M_UNKNOWN", "No membership event was found, room was never joined")
  (true, "", "")

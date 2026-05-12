const
  RustPath* = "api/client/membership/kick.rs"
  RustCrate* = "api"

import std/json

type
  KickPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc kickMembership*(): string =
  "leave"

proc kickResponse*(): JsonNode =
  newJObject()

proc kickPolicy*(senderUserId, targetUserId: string): KickPolicyResult =
  if targetUserId.len == 0:
    return (false, "M_BAD_JSON", "user_id is required.")
  if senderUserId.len > 0 and senderUserId == targetUserId:
    return (false, "M_FORBIDDEN", "You cannot kick yourself.")
  (true, "", "")

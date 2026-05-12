const
  RustPath* = "api/client/membership/unban.rs"
  RustCrate* = "api"

import std/json

type
  UnbanPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc unbanMembership*(): string =
  "leave"

proc unbanResponse*(): JsonNode =
  newJObject()

proc unbanPolicy*(targetUserId: string): UnbanPolicyResult =
  if targetUserId.len == 0:
    return (false, "M_BAD_JSON", "user_id is required.")
  (true, "", "")

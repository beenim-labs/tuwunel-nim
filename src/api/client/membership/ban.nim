const
  RustPath* = "api/client/membership/ban.rs"
  RustCrate* = "api"

import std/json

type
  BanPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc banMembership*(): string =
  "ban"

proc banResponse*(): JsonNode =
  newJObject()

proc banPolicy*(senderUserId, targetUserId: string): BanPolicyResult =
  if targetUserId.len == 0:
    return (false, "M_BAD_JSON", "user_id is required.")
  if senderUserId.len > 0 and senderUserId == targetUserId:
    return (false, "M_FORBIDDEN", "You cannot ban yourself.")
  (true, "", "")

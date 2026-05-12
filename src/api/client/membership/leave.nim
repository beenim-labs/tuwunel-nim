const
  RustPath* = "api/client/membership/leave.rs"
  RustCrate* = "api"

import std/json

proc leaveMembership*(): string =
  "leave"

proc leaveResponse*(): JsonNode =
  newJObject()

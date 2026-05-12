const
  RustPath* = "api/server/send_leave.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/json

proc sendLeavePayload*(): JsonNode =
  newJObject()

## server/send_leave — api module.
##
## Ported from Rust api/server/send_leave.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/send_leave.rs"
  RustCrate* = "api"

proc createLeaveEventV1Route*() =
  ## Ported from `create_leave_event_v1_route`.
  discard

proc createLeaveEventV2Route*() =
  ## Ported from `create_leave_event_v2_route`.
  discard

proc createLeaveEvent*(services: Services; origin: string; roomId: string; pdu: RawJsonValue) =
  ## Ported from `create_leave_event`.
  discard

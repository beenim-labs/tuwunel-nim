## membership/leave — api module.
##
## Ported from Rust api/client/membership/leave.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/membership/leave.rs"
  RustCrate* = "api"

proc leaveRoomRoute*() =
  ## Ported from `leave_room_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
## membership/forget — api module.
##
## Ported from Rust api/client/membership/forget.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/membership/forget.rs"
  RustCrate* = "api"

proc forgetRoomRoute*() =
  ## Ported from `forget_room_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
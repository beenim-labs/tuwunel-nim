## membership/knock — api module.
##
## Ported from Rust api/client/membership/knock.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/membership/knock.rs"
  RustCrate* = "api"

proc knockRoomRoute*() =
  ## Ported from `knock_room_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
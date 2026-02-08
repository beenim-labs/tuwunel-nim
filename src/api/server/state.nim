## server/state — api module.
##
## Ported from Rust api/server/state.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/state.rs"
  RustCrate* = "api"

proc getRoomStateRoute*() =
  ## Ported from `get_room_state_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
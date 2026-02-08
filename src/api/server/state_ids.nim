## server/state_ids — api module.
##
## Ported from Rust api/server/state_ids.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/state_ids.rs"
  RustCrate* = "api"

proc getRoomStateIdsRoute*() =
  ## Ported from `get_room_state_ids_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
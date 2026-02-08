## query/room_state_cache — admin module.
##
## Ported from Rust admin/query/room_state_cache.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/query/room_state_cache.rs"
  RustCrate* = "admin"

proc process*(subcommand: RoomStateCacheCommand; context: Context<'_>) =
  ## Ported from `process`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
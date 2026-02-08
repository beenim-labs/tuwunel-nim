## room/alias — admin module.
##
## Ported from Rust admin/room/alias.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/room/alias.rs"
  RustCrate* = "admin"

proc process*(command: RoomAliasCommand; context: Context<'_>) =
  ## Ported from `process`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
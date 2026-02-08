## query/room_alias — admin module.
##
## Ported from Rust admin/query/room_alias.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/query/room_alias.rs"
  RustCrate* = "admin"

proc process*(subcommand: RoomAliasCommand; context: Context<'_>) =
  ## Ported from `process`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
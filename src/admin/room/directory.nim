## room/directory — admin module.
##
## Ported from Rust admin/room/directory.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/room/directory.rs"
  RustCrate* = "admin"

proc process*(command: RoomDirectoryCommand; context: Context<'_>) =
  ## Ported from `process`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
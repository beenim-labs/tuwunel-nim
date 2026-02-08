## room/event — api module.
##
## Ported from Rust api/client/room/event.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/room/event.rs"
  RustCrate* = "api"

proc getRoomEventRoute*() =
  ## Ported from `get_room_event_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
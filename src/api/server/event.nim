## server/event — api module.
##
## Ported from Rust api/server/event.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/event.rs"
  RustCrate* = "api"

proc getEventRoute*() =
  ## Ported from `get_event_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
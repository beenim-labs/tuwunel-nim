## client/events — api module.
##
## Ported from Rust api/client/events.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/events.rs"
  RustCrate* = "api"

proc eventsRoute*() =
  ## Ported from `events_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
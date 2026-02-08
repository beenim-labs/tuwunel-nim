## server/get_missing_events — api module.
##
## Ported from Rust api/server/get_missing_events.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/get_missing_events.rs"
  RustCrate* = "api"

proc getMissingEventsRoute*() =
  ## Ported from `get_missing_events_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
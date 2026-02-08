## room/initial_sync — api module.
##
## Ported from Rust api/client/room/initial_sync.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/room/initial_sync.rs"
  RustCrate* = "api"

proc roomInitialSyncRoute*() =
  ## Ported from `room_initial_sync_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
## server/backfill — api module.
##
## Ported from Rust api/server/backfill.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/backfill.rs"
  RustCrate* = "api"

proc getBackfillRoute*() =
  ## Ported from `get_backfill_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
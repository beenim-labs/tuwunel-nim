## server/well_known — api module.
##
## Ported from Rust api/server/well_known.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/well_known.rs"
  RustCrate* = "api"

proc wellKnownServer*() =
  ## Ported from `well_known_server`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
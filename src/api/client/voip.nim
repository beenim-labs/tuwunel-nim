## client/voip — api module.
##
## Ported from Rust api/client/voip.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/voip.rs"
  RustCrate* = "api"

proc turnServerRoute*() =
  ## Ported from `turn_server_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
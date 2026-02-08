## server/utils — api module.
##
## Ported from Rust api/server/utils.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/utils.rs"
  RustCrate* = "api"

proc check*() =
  ## Ported from `check`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
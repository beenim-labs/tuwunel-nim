## client/context — api module.
##
## Ported from Rust api/client/context.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/context.rs"
  RustCrate* = "api"

proc getContextRoute*() =
  ## Ported from `get_context_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
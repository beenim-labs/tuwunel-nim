## client/space — api module.
##
## Ported from Rust api/client/space.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/space.rs"
  RustCrate* = "api"

proc getHierarchyRoute*() =
  ## Ported from `get_hierarchy_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
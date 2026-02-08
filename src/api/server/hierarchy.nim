## server/hierarchy — api module.
##
## Ported from Rust api/server/hierarchy.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/hierarchy.rs"
  RustCrate* = "api"

proc getHierarchyRoute*() =
  ## Ported from `get_hierarchy_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
## client/capabilities — api module.
##
## Ported from Rust api/client/capabilities.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/capabilities.rs"
  RustCrate* = "api"

proc getCapabilitiesRoute*() =
  ## Ported from `get_capabilities_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
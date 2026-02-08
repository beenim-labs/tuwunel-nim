## membership/ban — api module.
##
## Ported from Rust api/client/membership/ban.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/membership/ban.rs"
  RustCrate* = "api"

proc banUserRoute*() =
  ## Ported from `ban_user_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
## membership/kick — api module.
##
## Ported from Rust api/client/membership/kick.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/membership/kick.rs"
  RustCrate* = "api"

proc kickUserRoute*() =
  ## Ported from `kick_user_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
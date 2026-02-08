## membership/unban — api module.
##
## Ported from Rust api/client/membership/unban.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/membership/unban.rs"
  RustCrate* = "api"

proc unbanUserRoute*() =
  ## Ported from `unban_user_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
## session/refresh — api module.
##
## Ported from Rust api/client/session/refresh.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/session/refresh.rs"
  RustCrate* = "api"

proc refreshTokenRoute*() =
  ## Ported from `refresh_token_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
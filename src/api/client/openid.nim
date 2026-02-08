## client/openid — api module.
##
## Ported from Rust api/client/openid.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/openid.rs"
  RustCrate* = "api"

proc createOpenidTokenRoute*() =
  ## Ported from `create_openid_token_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
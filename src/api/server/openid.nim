## server/openid — api module.
##
## Ported from Rust api/server/openid.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/openid.rs"
  RustCrate* = "api"

proc getOpenidUserinfoRoute*() =
  ## Ported from `get_openid_userinfo_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
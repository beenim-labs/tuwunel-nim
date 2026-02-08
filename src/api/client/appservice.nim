## client/appservice — api module.
##
## Ported from Rust api/client/appservice.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/appservice.rs"
  RustCrate* = "api"

proc appservicePing*() =
  ## Ported from `appservice_ping`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
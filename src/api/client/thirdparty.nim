## client/thirdparty — api module.
##
## Ported from Rust api/client/thirdparty.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/thirdparty.rs"
  RustCrate* = "api"

proc getProtocolsRoute*(Body: Ruma<get_protocols::v3::Request>): get_protocols::v3::Response =
  ## Ported from `get_protocols_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
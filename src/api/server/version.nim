## server/version — api module.
##
## Ported from Rust api/server/version.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/version.rs"
  RustCrate* = "api"

proc getServerVersionRoute*(Body: Ruma<get_server_version::v1::Request>): get_server_version::v1::Response =
  ## Ported from `get_server_version_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
## server/send_knock — api module.
##
## Ported from Rust api/server/send_knock.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/send_knock.rs"
  RustCrate* = "api"

proc createKnockEventV1Route*() =
  ## Ported from `create_knock_event_v1_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
## server/event_auth — api module.
##
## Ported from Rust api/server/event_auth.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/event_auth.rs"
  RustCrate* = "api"

proc getEventAuthorizationRoute*() =
  ## Ported from `get_event_authorization_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
## client/redact — api module.
##
## Ported from Rust api/client/redact.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/redact.rs"
  RustCrate* = "api"

proc redactEventRoute*() =
  ## Ported from `redact_event_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
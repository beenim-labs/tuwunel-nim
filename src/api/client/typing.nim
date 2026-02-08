## client/typing — api module.
##
## Ported from Rust api/client/typing.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/typing.rs"
  RustCrate* = "api"

proc createTypingEventRoute*() =
  ## Ported from `create_typing_event_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
## client/send — api module.
##
## Ported from Rust api/client/send.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/send.rs"
  RustCrate* = "api"

proc sendMessageEventRoute*() =
  ## Ported from `send_message_event_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
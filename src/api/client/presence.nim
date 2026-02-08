## client/presence — api module.
##
## Ported from Rust api/client/presence.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/presence.rs"
  RustCrate* = "api"

proc setPresenceRoute*() =
  ## Ported from `set_presence_route`.
  discard

proc getPresenceRoute*() =
  ## Ported from `get_presence_route`.
  discard

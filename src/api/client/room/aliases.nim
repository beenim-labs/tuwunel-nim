## room/aliases — api module.
##
## Ported from Rust api/client/room/aliases.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/room/aliases.rs"
  RustCrate* = "api"

proc getRoomAliasesRoute*() =
  ## Ported from `get_room_aliases_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
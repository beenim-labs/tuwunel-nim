## server/publicrooms — api module.
##
## Ported from Rust api/server/publicrooms.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/publicrooms.rs"
  RustCrate* = "api"

proc getPublicRoomsFilteredRoute*() =
  ## Ported from `get_public_rooms_filtered_route`.
  discard

proc getPublicRoomsRoute*() =
  ## Ported from `get_public_rooms_route`.
  discard

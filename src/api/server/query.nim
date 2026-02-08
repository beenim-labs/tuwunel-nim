## server/query — api module.
##
## Ported from Rust api/server/query.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/query.rs"
  RustCrate* = "api"

proc getRoomInformationRoute*() =
  ## Ported from `get_room_information_route`.
  discard

proc getProfileInformationRoute*() =
  ## Ported from `get_profile_information_route`.
  discard

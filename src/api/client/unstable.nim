## client/unstable — api module.
##
## Ported from Rust api/client/unstable.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/unstable.rs"
  RustCrate* = "api"

proc getMutualRoomsRoute*() =
  ## Ported from `get_mutual_rooms_route`.
  discard

proc deleteTimezoneKeyRoute*() =
  ## Ported from `delete_timezone_key_route`.
  discard

proc setTimezoneKeyRoute*() =
  ## Ported from `set_timezone_key_route`.
  discard

proc setProfileFieldRoute*() =
  ## Ported from `set_profile_field_route`.
  discard

proc deleteProfileFieldRoute*() =
  ## Ported from `delete_profile_field_route`.
  discard

proc getTimezoneKeyRoute*() =
  ## Ported from `get_timezone_key_route`.
  discard

proc getProfileFieldRoute*() =
  ## Ported from `get_profile_field_route`.
  discard

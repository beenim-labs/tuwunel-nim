## room/moderation — admin module.
##
## Ported from Rust admin/room/moderation.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/room/moderation.rs"
  RustCrate* = "admin"

proc banRoom*(room: OwnedRoomOrAliasId) =
  ## Ported from `ban_room`.
  discard

proc banListOfRooms*() =
  ## Ported from `ban_list_of_rooms`.
  discard

proc unbanRoom*(room: OwnedRoomOrAliasId) =
  ## Ported from `unban_room`.
  discard

proc listBannedRooms*(noDetails: bool) =
  ## Ported from `list_banned_rooms`.
  discard

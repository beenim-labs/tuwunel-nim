## query/room_timeline — admin module.
##
## Ported from Rust admin/query/room_timeline.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/query/room_timeline.rs"
  RustCrate* = "admin"

proc last*(roomId: OwnedRoomOrAliasId) =
  ## Ported from `last`.
  discard

proc pdus*(roomId: OwnedRoomOrAliasId; from: Option[string]; limit: Option[int]) =
  ## Ported from `pdus`.
  discard

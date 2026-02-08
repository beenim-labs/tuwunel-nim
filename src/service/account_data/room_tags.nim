## account_data/room_tags — service module.
##
## Ported from Rust service/account_data/room_tags.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/account_data/room_tags.rs"
  RustCrate* = "service"

proc setRoomTag*(userId: string; roomId: string; tag: TagName; info: Option[TagInfo]) =
  ## Ported from `set_room_tag`.
  discard

proc getRoomTags*(userId: string; roomId: string): Tags =
  ## Ported from `get_room_tags`.
  discard

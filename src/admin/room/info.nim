## room/info — admin module.
##
## Ported from Rust admin/room/info.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/room/info.rs"
  RustCrate* = "admin"

proc listJoinedMembers*(roomId: string; localOnly: bool) =
  ## Ported from `list_joined_members`.
  discard

proc viewRoomTopic*(roomId: string) =
  ## Ported from `view_room_topic`.
  discard

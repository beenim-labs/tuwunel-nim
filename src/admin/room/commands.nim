## room/commands — admin module.
##
## Ported from Rust admin/room/commands.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/room/commands.rs"
  RustCrate* = "admin"

proc listRooms*(page: Option[int]; excludeDisabled: bool; excludeBanned: bool; noDetails: bool) =
  ## Ported from `list_rooms`.
  discard

proc exists*(roomId: string) =
  ## Ported from `exists`.
  discard

proc deleteRoom*(roomId: string; force: bool) =
  ## Ported from `delete_room`.
  discard

## query/short — admin module.
##
## Ported from Rust admin/query/short.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/query/short.rs"
  RustCrate* = "admin"

proc shortEventId*(eventId: string) =
  ## Ported from `short_event_id`.
  discard

proc shortRoomId*(roomId: OwnedRoomOrAliasId) =
  ## Ported from `short_room_id`.
  discard

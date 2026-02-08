## server/send_join — api module.
##
## Ported from Rust api/server/send_join.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/send_join.rs"
  RustCrate* = "api"

proc createJoinEvent*(services: Services; origin: string; roomId: string; pdu: RawJsonValue): create_join_event::v1::RoomState =
  ## Ported from `create_join_event`.
  discard

proc createJoinEventV1Route*() =
  ## Ported from `create_join_event_v1_route`.
  discard

proc createJoinEventV2Route*() =
  ## Ported from `create_join_event_v2_route`.
  discard

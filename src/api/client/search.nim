## client/search — api module.
##
## Ported from Rust api/client/search.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/search.rs"
  RustCrate* = "api"

proc searchEventsRoute*() =
  ## Ported from `search_events_route`.
  discard

proc categoryRoomEvents*(services: Services; senderUser: string; nextBatch: Option[string]; criteria: Criteria): RoomEvents =
  ## Ported from `category_room_events`.
  discard

proc procureRoomState*(services: Services; roomId: string): RoomState =
  ## Ported from `procure_room_state`.
  discard

proc checkRoomVisible*(services: Services; userId: string; roomId: string; search: Criteria) =
  ## Ported from `check_room_visible`.
  discard

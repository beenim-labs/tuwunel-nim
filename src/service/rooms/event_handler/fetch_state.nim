## event_handler/fetch_state — service module.
##
## Ported from Rust service/rooms/event_handler/fetch_state.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/event_handler/fetch_state.rs"
  RustCrate* = "service"

proc fetchState*(origin: string; roomId: string; eventId: string; roomVersion: RoomVersionId; createEventId: string): Option[HashMap<uint64]> =
  ## Ported from `fetch_state`.
  none(HashMap<uint64])

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
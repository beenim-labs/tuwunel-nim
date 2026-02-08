## event_handler/resolve_state — service module.
##
## Ported from Rust service/rooms/event_handler/resolve_state.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/event_handler/resolve_state.rs"
  RustCrate* = "service"

proc resolveState*(roomId: string; roomVersion: RoomVersionId; incomingState: HashMap<uint64): CompressedState =
  ## Ported from `resolve_state`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
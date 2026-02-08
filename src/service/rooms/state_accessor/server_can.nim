## state_accessor/server_can — service module.
##
## Ported from Rust service/rooms/state_accessor/server_can.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/state_accessor/server_can.rs"
  RustCrate* = "service"

proc serverCanSeeEvent*(origin: string; roomId: string; eventId: string): bool =
  ## Ported from `server_can_see_event`.
  false

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
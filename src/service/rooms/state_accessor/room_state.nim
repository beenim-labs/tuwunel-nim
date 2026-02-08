## state_accessor/room_state — service module.
##
## Ported from Rust service/rooms/state_accessor/room_state.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/state_accessor/room_state.rs"
  RustCrate* = "service"

proc roomStateGetId*(roomId: string; eventType: StateEventType; stateKey: string): string =
  ## Ported from `room_state_get_id`.
  ""

proc roomStateGet*(roomId: string; eventType: StateEventType; stateKey: string): Pdu =
  ## Ported from `room_state_get`.
  discard

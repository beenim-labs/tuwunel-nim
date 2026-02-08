## event_handler/state_at_incoming — service module.
##
## Ported from Rust service/rooms/event_handler/state_at_incoming.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/event_handler/state_at_incoming.rs"
  RustCrate* = "service"

## Minimal public API — service integration via database.
proc init*() =
  discard
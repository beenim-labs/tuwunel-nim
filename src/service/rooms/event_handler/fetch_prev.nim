## event_handler/fetch_prev — service module.
##
## Ported from Rust service/rooms/event_handler/fetch_prev.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/event_handler/fetch_prev.rs"
  RustCrate* = "service"

## Minimal public API — service integration via database.
proc init*() =
  discard
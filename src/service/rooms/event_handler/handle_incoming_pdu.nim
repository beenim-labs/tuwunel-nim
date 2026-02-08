## event_handler/handle_incoming_pdu — service module.
##
## Ported from Rust service/rooms/event_handler/handle_incoming_pdu.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/event_handler/handle_incoming_pdu.rs"
  RustCrate* = "service"

## Minimal public API — service integration via database.
proc init*() =
  discard
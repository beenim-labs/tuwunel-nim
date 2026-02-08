## event_handler/handle_prev_pdu — service module.
##
## Ported from Rust service/rooms/event_handler/handle_prev_pdu.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/event_handler/handle_prev_pdu.rs"
  RustCrate* = "service"

proc handlePrevPdu*(origin: string; roomId: string; eventId: string; eventidInfo: Option<(PduEvent) =
  ## Ported from `handle_prev_pdu`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
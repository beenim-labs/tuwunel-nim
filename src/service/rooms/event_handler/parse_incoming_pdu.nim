## event_handler/parse_incoming_pdu — service module.
##
## Ported from Rust service/rooms/event_handler/parse_incoming_pdu.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/event_handler/parse_incoming_pdu.rs"
  RustCrate* = "service"

proc parseIncomingPdu*(pdu: RawJsonValue): Parsed =
  ## Ported from `parse_incoming_pdu`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
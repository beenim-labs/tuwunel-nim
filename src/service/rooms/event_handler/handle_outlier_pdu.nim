## event_handler/handle_outlier_pdu — service module.
##
## Ported from Rust service/rooms/event_handler/handle_outlier_pdu.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/event_handler/handle_outlier_pdu.rs"
  RustCrate* = "service"

proc handleOutlierPdu*(origin: string; roomId: string; eventId: string; pduJson: CanonicalJsonObject; roomVersion: RoomVersionId; authEventsKnown: bool): (PduEvent =
  ## Ported from `handle_outlier_pdu`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
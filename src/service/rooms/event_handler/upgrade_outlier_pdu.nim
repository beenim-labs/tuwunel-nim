## event_handler/upgrade_outlier_pdu — service module.
##
## Ported from Rust service/rooms/event_handler/upgrade_outlier_pdu.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/event_handler/upgrade_outlier_pdu.rs"
  RustCrate* = "service"

proc upgradeOutlierToTimelinePdu*(origin: string; roomId: string; incomingPdu: PduEvent; val: CanonicalJsonObject; roomVersion: RoomVersionId; createEventId: string): Option[(RawPduId] =
  ## Ported from `upgrade_outlier_to_timeline_pdu`.
  none((RawPduId)

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
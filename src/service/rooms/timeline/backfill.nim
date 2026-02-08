## timeline/backfill — service module.
##
## Ported from Rust service/rooms/timeline/backfill.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/timeline/backfill.rs"
  RustCrate* = "service"

proc backfillIfRequired*(roomId: string; from: PduCount) =
  ## Ported from `backfill_if_required`.
  discard

proc backfillPdu*(roomId: string; origin: string; pdu: RootRef) =
  ## Ported from `backfill_pdu`.
  discard

proc prependBackfillPdu*(pduId: RawPduId; eventId: string; json: CanonicalJsonObject) =
  ## Ported from `prepend_backfill_pdu`.
  discard

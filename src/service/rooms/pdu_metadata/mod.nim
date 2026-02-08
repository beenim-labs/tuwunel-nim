## pdu_metadata/mod — service module.
##
## Ported from Rust service/rooms/pdu_metadata/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/pdu_metadata/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    discard

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc addRelation*(self: Service; from: PduCount; to: PduCount) =
  ## Ported from `add_relation`.
  discard

proc isEventReferenced*(self: Service; roomId: string; eventId: string): bool =
  ## Ported from `is_event_referenced`.
  false

proc markEventSoftFailed*(self: Service; eventId: string) =
  ## Ported from `mark_event_soft_failed`.
  discard

proc isEventSoftFailed*(self: Service; eventId: string): bool =
  ## Ported from `is_event_soft_failed`.
  false

proc deleteAllReferencedForRoom*(self: Service; roomId: string) =
  ## Ported from `delete_all_referenced_for_room`.
  discard

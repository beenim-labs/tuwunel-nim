## server_keys/verify — service module.
##
## Ported from Rust service/server_keys/verify.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/server_keys/verify.rs"
  RustCrate* = "service"

proc validateAndAddEventId*(pdu: RawJsonValue; roomVersionId: RoomVersionId): (string =
  ## Ported from `validate_and_add_event_id`.
  discard

proc validateAndAddEventIdNoFetch*(pdu: RawJsonValue; roomVersionId: RoomVersionId): (string =
  ## Ported from `validate_and_add_event_id_no_fetch`.
  discard

proc verifyEvent*(event: CanonicalJsonObject; roomVersionId: Option[RoomVersionId]): Verified =
  ## Ported from `verify_event`.
  discard

proc verifyJson*(event: CanonicalJsonObject; roomVersionId: Option[RoomVersionId]) =
  ## Ported from `verify_json`.
  discard

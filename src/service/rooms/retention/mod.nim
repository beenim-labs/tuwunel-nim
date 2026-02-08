## retention/mod — service module.
##
## Ported from Rust service/rooms/retention/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/retention/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    discard

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc worker*(self: Service) =
  ## Ported from `worker`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc getOriginalPdu*(self: Service; eventId: string): PduEvent =
  ## Ported from `get_original_pdu`.
  discard

proc getOriginalPduJson*(self: Service; eventId: string): CanonicalJsonObject =
  ## Ported from `get_original_pdu_json`.
  discard

proc saveOriginalPdu*(self: Service; eventId: string; pdu: CanonicalJsonObject) =
  ## Ported from `save_original_pdu`.
  discard

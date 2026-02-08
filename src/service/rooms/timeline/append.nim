## timeline/append — service module.
##
## Ported from Rust service/rooms/timeline/append.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/timeline/append.rs"
  RustCrate* = "service"

proc appendPduEffects*(pduId: RawPduId; pdu: PduEvent; shortroomid: Shortstring; count: PduCount) =
  ## Ported from `append_pdu_effects`.
  discard

proc appendPduJson*(pduId: RawPduId; pdu: PduEvent; json: CanonicalJsonObject; count: PduCount) =
  ## Ported from `append_pdu_json`.
  discard

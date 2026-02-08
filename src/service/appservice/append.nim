## appservice/append — service module.
##
## Ported from Rust service/appservice/append.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/appservice/append.rs"
  RustCrate* = "service"

proc appendPdu*(pduId: RawPduId; pdu: Pdu) =
  ## Ported from `append_pdu`.
  discard

proc appendPduTo*(appservice: RegistrationInfo; pduId: RawPduId; pdu: Pdu) =
  ## Ported from `append_pdu_to`.
  discard

proc shouldAppendTo*(appservice: RegistrationInfo; pdu: Pdu): bool =
  ## Ported from `should_append_to`.
  false

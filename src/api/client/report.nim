## client/report — api module.
##
## Ported from Rust api/client/report.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/report.rs"
  RustCrate* = "api"

proc reportRoomRoute*() =
  ## Ported from `report_room_route`.
  discard

proc reportEventRoute*() =
  ## Ported from `report_event_route`.
  discard

proc isEventReportValid*(services: Services; eventId: string; roomId: string; senderUser: string; reason: Option[stringing]; score: Option[ruma::Int]; pdu: PduEvent) =
  ## Ported from `is_event_report_valid`.
  discard

proc delayResponse*() =
  ## Ported from `delay_response`.
  discard

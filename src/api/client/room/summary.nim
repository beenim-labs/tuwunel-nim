## room/summary — api module.
##
## Ported from Rust api/client/room/summary.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/room/summary.rs"
  RustCrate* = "api"

proc getRoomSummaryLegacy*() =
  ## Ported from `get_room_summary_legacy`.
  discard

proc getRoomSummary*() =
  ## Ported from `get_room_summary`.
  discard

proc roomSummaryResponse*(services: Services; roomId: string; servers: [string]; senderUser: Option[string]): get_summary::v1::Response =
  ## Ported from `room_summary_response`.
  discard

proc localRoomSummaryResponse*(services: Services; roomId: string; senderUser: Option[string]): get_summary::v1::Response =
  ## Ported from `local_room_summary_response`.
  discard

proc remoteRoomSummaryHierarchyResponse*(services: Services; roomId: string; servers: [string]; senderUser: Option[string]): SpaceHierarchyParentSummary =
  ## Ported from `remote_room_summary_hierarchy_response`.
  discard

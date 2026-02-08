## v5/filter — api module.
##
## Ported from Rust api/client/sync/v5/filter.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/sync/v5/filter.rs"
  RustCrate* = "api"

proc filterRoom*(filter: ListFilters; roomId: string; membership: Option[MembershipState]): bool =
  ## Ported from `filter_room`.
  false

proc filterRoomMeta*(roomId: string): bool =
  ## Ported from `filter_room_meta`.
  false

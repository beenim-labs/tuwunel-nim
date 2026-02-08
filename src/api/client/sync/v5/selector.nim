## v5/selector — api module.
##
## Ported from Rust api/client/sync/v5/selector.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/sync/v5/selector.rs"
  RustCrate* = "api"

proc selector*(conn: mut Connection; syncInfo: SyncInfo<'_>): (Window, ResponseLists) =
  ## Ported from `selector`.
  discard

proc matcher*(syncInfo: SyncInfo<'_>; conn: Connection; roomId: string; membership: Option[MembershipState]): Option[WindowRoom] =
  ## Ported from `matcher`.
  none(WindowRoom)

proc roomSort*(a: WindowRoom; b: WindowRoom): Ordering =
  ## Ported from `room_sort`.
  discard

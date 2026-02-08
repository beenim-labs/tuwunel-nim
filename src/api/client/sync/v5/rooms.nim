## v5/rooms — api module.
##
## Ported from Rust api/client/sync/v5/rooms.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/sync/v5/rooms.rs"
  RustCrate* = "api"

proc handle*(syncInfo: SyncInfo<'_>; conn: Connection; window: Window): BTreeMap<string> =
  ## Ported from `handle`.
  discard

proc handleRoom*(conn: Connection): response::Room =
  ## Ported from `handle_room`.
  discard

proc calculateHeroes*(services: Services; senderUser: string; roomId: string; roomName: Option[DisplayName]; roomAvatar: Option[MxcUri]): (Option[Heroes], Option[DisplayName], Option[string]) =
  ## Ported from `calculate_heroes`.
  discard

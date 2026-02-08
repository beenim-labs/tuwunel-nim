## membership/mod — api module.
##
## Ported from Rust api/client/membership/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/membership/mod.rs"
  RustCrate* = "api"

proc joinedRoomsRoute*() =
  ## Ported from `joined_rooms_route`.
  discard

proc bannedRoomCheck*(services: Services; userId: string; roomId: string; origRoomId: Option[RoomOrAliasId]; clientIp: IpAddr) =
  ## Ported from `banned_room_check`.
  discard

proc maybeDeactivate*(services: Services; userId: string; clientIp: IpAddr) =
  ## Ported from `maybe_deactivate`.
  discard

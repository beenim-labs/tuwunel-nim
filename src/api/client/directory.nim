## client/directory — api module.
##
## Ported from Rust api/client/directory.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/directory.rs"
  RustCrate* = "api"

proc getPublicRoomsFilteredRoute*() =
  ## Ported from `get_public_rooms_filtered_route`.
  discard

proc getPublicRoomsRoute*() =
  ## Ported from `get_public_rooms_route`.
  discard

proc setRoomVisibilityRoute*() =
  ## Ported from `set_room_visibility_route`.
  discard

proc getRoomVisibilityRoute*() =
  ## Ported from `get_room_visibility_route`.
  discard

proc getPublicRoomsFilteredHelper*(services: Services; server: Option[string]; limit: Option[UInt]; since: Option[string]; filter: Filter; Network: RoomNetwork): get_public_rooms_filtered::v3::Response =
  ## Ported from `get_public_rooms_filtered_helper`.
  discard

proc userCanPublishRoom*(services: Services; userId: string; roomId: string): bool =
  ## Ported from `user_can_publish_room`.
  false

proc publicRoomsChunk*(services: Services; roomId: string): PublicRoomsChunk =
  ## Ported from `public_rooms_chunk`.
  discard

proc checkServerBanned*(services: Services; server: Option[string]) =
  ## Ported from `check_server_banned`.
  discard

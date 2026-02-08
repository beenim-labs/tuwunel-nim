## user/commands — admin module.
##
## Ported from Rust admin/user/commands.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/user/commands.rs"
  RustCrate* = "admin"

proc listUsers*() =
  ## Ported from `list_users`.
  discard

proc createUser*(username: string; password: Option[string]) =
  ## Ported from `create_user`.
  discard

proc deactivate*(noLeaveRooms: bool; userId: string) =
  ## Ported from `deactivate`.
  discard

proc deleteDevice*(userId: string; deviceId: OwnedDeviceId) =
  ## Ported from `delete_device`.
  discard

proc resetPassword*(username: string; password: Option[string]) =
  ## Ported from `reset_password`.
  discard

proc deactivateAll*(noLeaveRooms: bool; force: bool) =
  ## Ported from `deactivate_all`.
  discard

proc deactivateUser*(services: Services; userId: string; noLeaveRooms: bool) =
  ## Ported from `deactivate_user`.
  discard

proc listJoinedRooms*(userId: string) =
  ## Ported from `list_joined_rooms`.
  discard

proc forceJoinListOfLocalUsers*(room: OwnedRoomOrAliasId; yesIWantToDoThis: bool) =
  ## Ported from `force_join_list_of_local_users`.
  discard

proc forceJoinAllLocalUsers*(room: OwnedRoomOrAliasId; yesIWantToDoThis: bool) =
  ## Ported from `force_join_all_local_users`.
  discard

proc forceJoinRoom*(userId: string; room: OwnedRoomOrAliasId) =
  ## Ported from `force_join_room`.
  discard

proc forceLeaveRoom*(userId: string; roomId: OwnedRoomOrAliasId) =
  ## Ported from `force_leave_room`.
  discard

proc forceDemote*(userId: string; roomId: OwnedRoomOrAliasId) =
  ## Ported from `force_demote`.
  discard

proc forcePromote*(targetId: string; roomId: OwnedRoomOrAliasId) =
  ## Ported from `force_promote`.
  discard

proc makeUserAdmin*(userId: string) =
  ## Ported from `make_user_admin`.
  discard

proc putRoomTag*(userId: string; roomId: string; tag: string) =
  ## Ported from `put_room_tag`.
  discard

proc deleteRoomTag*(userId: string; roomId: string; tag: string) =
  ## Ported from `delete_room_tag`.
  discard

proc getRoomTags*(userId: string; roomId: string) =
  ## Ported from `get_room_tags`.
  discard

proc redactEvent*(eventId: string) =
  ## Ported from `redact_event`.
  discard

proc lastActive*(limit: Option[int]) =
  ## Ported from `last_active`.
  discard

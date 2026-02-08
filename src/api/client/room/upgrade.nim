## room/upgrade — api module.
##
## Ported from Rust api/client/room/upgrade.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/room/upgrade.rs"
  RustCrate* = "api"

proc upgradeRoomRoute*() =
  ## Ported from `upgrade_room_route`.
  discard

proc upgradeRoomCreate*(services: Services; senderUser: string; oldRoomId: string; newVersion: RoomVersionId; versionRules: RoomVersionRules; predecessor: PreviousRoom; additionalCreators: seq[string]): (string =
  ## Ported from `upgrade_room_create`.
  discard

proc upgradeRoomCreateLegacy*(services: Services; senderUser: string; oldRoomId: string; newVersion: RoomVersionId; versionRules: RoomVersionRules; predecessor: PreviousRoom): (string =
  ## Ported from `upgrade_room_create_legacy`.
  discard

proc transferRoom*() =
  ## Ported from `transfer_room`.
  discard

proc moveJoinedMember*(): string =
  ## Ported from `move_joined_member`.
  ""

proc moveStateEvents*() =
  ## Ported from `move_state_events`.
  discard

proc moveLocalAliases*() =
  ## Ported from `move_local_aliases`.
  discard

proc tombstoneOldRoom*(): string =
  ## Ported from `tombstone_old_room`.
  ""

proc lockdownOldRoom*(): string =
  ## Ported from `lockdown_old_room`.
  ""

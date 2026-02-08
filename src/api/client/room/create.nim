## room/create — api module.
##
## Ported from Rust api/client/room/create.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/room/create.rs"
  RustCrate* = "api"

proc createRoomRoute*() =
  ## Ported from `create_room_route`.
  discard

proc createCreateEvent*(services: Services; body: Ruma<create_room::v3::Request>; preset: RoomPreset; roomVersion: RoomVersionId; versionRules: RoomVersionRules): (string =
  ## Ported from `create_create_event`.
  discard

proc createCreateEventLegacy*(services: Services; body: Ruma<create_room::v3::Request>; roomVersion: RoomVersionId; VersionRules: RoomVersionRules): (string =
  ## Ported from `create_create_event_legacy`.
  discard

proc defaultPowerLevelsContent*(versionRules: RoomVersionRules; powerLevelContentOverride: Option[Raw<RoomPowerLevelsEventContent]>; visibility: room::Visibility; users: BTreeMap<string): serde_json::Value =
  ## Ported from `default_power_levels_content`.
  discard

proc roomAliasCheck*(services: Services; roomAliasName: string; appserviceInfo: Option[RegistrationInfo]): OwnedRoomAliasId =
  ## Ported from `room_alias_check`.
  discard

proc customRoomIdCheck*(services: Services; customRoomId: string): string =
  ## Ported from `custom_room_id_check`.
  ""

proc canPublishDirectoryCheck*(services: Services; body: Ruma<create_room::v3::Request>) =
  ## Ported from `can_publish_directory_check`.
  discard

proc canCreateRoomCheck*(services: Services; body: Ruma<create_room::v3::Request>) =
  ## Ported from `can_create_room_check`.
  discard

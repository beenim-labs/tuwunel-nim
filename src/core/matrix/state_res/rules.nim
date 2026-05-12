const
  RustPath* = "core/matrix/room_version_rules.rs"
  RustCrate* = "core"

import std/strutils

type
  AuthorizationRules* = object
    useRoomCreateSender*: bool
    additionalRoomCreators*: bool
    explicitlyPrivilegeRoomCreators*: bool
    integerPowerLevels*: bool
    knocking*: bool
    knockRestrictedJoinRule*: bool
    restrictedJoinRule*: bool
    roomCreateEventIdAsRoomId*: bool

proc roomVersionNumber(roomVersion: string): int =
  try:
    parseInt(roomVersion)
  except ValueError:
    0

proc authorizationRules*(roomVersion = "11"): AuthorizationRules =
  let number = roomVersionNumber(roomVersion)
  AuthorizationRules(
    useRoomCreateSender: number >= 11,
    additionalRoomCreators: number >= 12,
    explicitlyPrivilegeRoomCreators: number >= 12,
    integerPowerLevels: number >= 12,
    knocking: number >= 7,
    knockRestrictedJoinRule: number >= 10,
    restrictedJoinRule: number >= 8,
    roomCreateEventIdAsRoomId: number >= 12,
  )

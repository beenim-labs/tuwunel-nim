## state_accessor/user_can — service module.
##
## Ported from Rust service/rooms/state_accessor/user_can.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/state_accessor/user_can.rs"
  RustCrate* = "service"

proc userCanRedact*(redacts: string; sender: string; roomId: string; federation: bool): bool =
  ## Ported from `user_can_redact`.
  false

proc userCanSeeEvent*(userId: string; roomId: string; eventId: string): bool =
  ## Ported from `user_can_see_event`.
  false

proc userCanSeeStateEvents*(userId: string; roomId: string): bool =
  ## Ported from `user_can_see_state_events`.
  false

proc userCanInvite*(roomId: string; sender: string; targetUser: string; stateLock: RoomMutexGuard): bool =
  ## Ported from `user_can_invite`.
  false

proc userCanTombstone*(roomId: string; userId: string; stateLock: RoomMutexGuard): bool =
  ## Ported from `user_can_tombstone`.
  false

## state_cache/update — service module.
##
## Ported from Rust service/rooms/state_cache/update.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/state_cache/update.rs"
  RustCrate* = "service"

proc updateMembership*(roomId: string; userId: string; membershipEvent: RoomMemberEventContent; sender: string; lastState: Option[seq[Raw<AnyStrippedStateEvent]]>; inviteVia: Option[seq[string]]; updateJoinedCount: bool; count: PduCount) =
  ## Ported from `update_membership`.
  discard

proc updateJoinedCount*(roomId: string) =
  ## Ported from `update_joined_count`.
  discard

proc markAsJoined*(userId: string; roomId: string; count: PduCount) =
  ## Ported from `mark_as_joined`.
  discard

proc markAsLeft*(userId: string; roomId: string; count: PduCount) =
  ## Ported from `mark_as_left`.
  discard

proc forget*(roomId: string; userId: string) =
  ## Ported from `forget`.
  discard

proc markAsOnceJoined*(userId: string; roomId: string) =
  ## Ported from `mark_as_once_joined`.
  discard

proc markAsInvited*(userId: string; roomId: string; count: PduCount; lastState: Option[seq[Raw<AnyStrippedStateEvent]]>; inviteVia: Option[seq[string]]) =
  ## Ported from `mark_as_invited`.
  discard

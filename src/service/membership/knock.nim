## membership/knock — service module.
##
## Ported from Rust service/membership/knock.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/membership/knock.rs"
  RustCrate* = "service"

proc knock*(senderUser: string; roomId: string; origServerName: Option[RoomOrAliasId]; reason: Option[string]; servers: [string]; stateLock: RoomMutexGuard) =
  ## Ported from `knock`.
  discard

proc knockRoomHelperLocal*(senderUser: string; roomId: string; reason: Option[string]; servers: [string]; stateLock: RoomMutexGuard) =
  ## Ported from `knock_room_helper_local`.
  discard

proc knockRoomHelperRemote*(senderUser: string; roomId: string; reason: Option[string]; servers: [string]; stateLock: RoomMutexGuard) =
  ## Ported from `knock_room_helper_remote`.
  discard

proc makeKnockRequest*(senderUser: string; roomId: string; servers: [string]): (federation::membership::prepare_knock_event::v1::Response =
  ## Ported from `make_knock_request`.
  discard

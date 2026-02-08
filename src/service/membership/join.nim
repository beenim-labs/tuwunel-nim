## membership/join — service module.
##
## Ported from Rust service/membership/join.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/membership/join.rs"
  RustCrate* = "service"

proc join*(senderUser: string; roomId: string; origRoomId: Option[RoomOrAliasId]; reason: Option[string]; servers: [string]; isAppservice: bool; stateLock: RoomMutexGuard) =
  ## Ported from `join`.
  discard

proc joinRemote*(senderUser: string; roomId: string; reason: Option[string]; servers: [string]; stateLock: RoomMutexGuard) =
  ## Ported from `join_remote`.
  discard

proc joinLocal*(senderUser: string; roomId: string; reason: Option[string]; servers: [string]; stateLock: RoomMutexGuard) =
  ## Ported from `join_local`.
  discard

proc createJoinEvent*(roomId: string; senderUser: string; joinEventStub: RawJsonValue; roomVersionId: RoomVersionId; roomVersionRules: RoomVersionRules; reason: Option[string]): (CanonicalJsonObject)> =
  ## Ported from `create_join_event`.
  discard

proc makeJoinRequest*(senderUser: string; roomId: string; servers: [string]): (federation::membership::prepare_join_event::v1::Response =
  ## Ported from `make_join_request`.
  discard

proc getServersForRoom*(services: Services; userId: string; roomId: string; origRoomId: Option[RoomOrAliasId]; via: [string]): seq[string] =
  ## Ported from `get_servers_for_room`.
  @[]

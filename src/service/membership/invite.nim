## membership/invite — service module.
##
## Ported from Rust service/membership/invite.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/membership/invite.rs"
  RustCrate* = "service"

proc invite*(senderUser: string; userId: string; roomId: string; reason: Option[stringing]; isDirect: bool) =
  ## Ported from `invite`.
  discard

proc remoteInvite*(senderUser: string; userId: string; roomId: string; reason: Option[stringing]; isDirect: bool) =
  ## Ported from `remote_invite`.
  discard

proc localInvite*(senderUser: string; userId: string; roomId: string; reason: Option[stringing]; isDirect: bool) =
  ## Ported from `local_invite`.
  discard

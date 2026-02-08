## membership/ban — service module.
##
## Ported from Rust service/membership/ban.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/membership/ban.rs"
  RustCrate* = "service"

proc ban*(roomId: string; userId: string; reason: Option[stringing]; senderUser: string; stateLock: RoomMutexGuard) =
  ## Ported from `ban`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
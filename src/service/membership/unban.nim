## membership/unban — service module.
##
## Ported from Rust service/membership/unban.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/membership/unban.rs"
  RustCrate* = "service"

proc unban*(roomId: string; userId: string; reason: Option[stringing]; senderUser: string; stateLock: RoomMutexGuard) =
  ## Ported from `unban`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
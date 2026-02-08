## membership/kick — service module.
##
## Ported from Rust service/membership/kick.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/membership/kick.rs"
  RustCrate* = "service"

proc kick*(roomId: string; userId: string; reason: Option[stringing]; senderUser: string; stateLock: RoomMutexGuard) =
  ## Ported from `kick`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
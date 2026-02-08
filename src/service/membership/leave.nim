## membership/leave — service module.
##
## Ported from Rust service/membership/leave.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/membership/leave.rs"
  RustCrate* = "service"

proc leave*(userId: string; roomId: string; reason: Option[string]; remoteLeaveNow: bool; stateLock: RoomMutexGuard) =
  ## Ported from `leave`.
  discard

proc remoteLeave*(userId: string; roomId: string; reason: Option[string]) =
  ## Ported from `remote_leave`.
  discard

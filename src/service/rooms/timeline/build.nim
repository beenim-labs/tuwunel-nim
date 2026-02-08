## timeline/build — service module.
##
## Ported from Rust service/rooms/timeline/build.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/timeline/build.rs"
  RustCrate* = "service"

proc buildAndAppendPdu*(pduBuilder: PduBuilder; sender: string; roomId: string; stateLock: RoomMutexGuard): string =
  ## Ported from `build_and_append_pdu`.
  ""

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
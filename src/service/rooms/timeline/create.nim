## timeline/create — service module.
##
## Ported from Rust service/rooms/timeline/create.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/timeline/create.rs"
  RustCrate* = "service"

proc createHashAndSignEvent*(pduBuilder: PduBuilder; sender: string; roomId: string; MutexLock: RoomMutexGuard): (PduEvent =
  ## Ported from `create_hash_and_sign_event`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
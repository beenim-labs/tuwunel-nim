## delete/mod — service module.
##
## Ported from Rust service/rooms/delete/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/delete/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    discard

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc deleteIfEmptyLocal*(self: Service; roomId: string; stateLock: RoomMutexGuard) =
  ## Ported from `delete_if_empty_local`.
  discard

proc deleteRoom*(self: Service; roomId: string; force: bool; stateLock: RoomMutexGuard) =
  ## Ported from `delete_room`.
  discard

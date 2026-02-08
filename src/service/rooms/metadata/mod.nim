## metadata/mod — service module.
##
## Ported from Rust service/rooms/metadata/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/metadata/mod.rs"
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

proc exists*(self: Service; roomId: string): bool =
  ## Ported from `exists`.
  false

proc iterIds*(self: Service): impl Stream<Item = string> + Send + '_ =
  ## Ported from `iter_ids`.
  discard

proc isPublic*(self: Service; roomId: string): bool =
  ## Ported from `is_public`.
  false

proc disableRoom*(self: Service; roomId: string) =
  ## Ported from `disable_room`.
  discard

proc enableRoom*(self: Service; roomId: string) =
  ## Ported from `enable_room`.
  discard

proc banRoom*(self: Service; roomId: string) =
  ## Ported from `ban_room`.
  discard

proc unbanRoom*(self: Service; roomId: string) =
  ## Ported from `unban_room`.
  discard

proc listBannedRooms*(self: Service): impl Stream<Item = string> + Send + '_ =
  ## Ported from `list_banned_rooms`.
  discard

proc isDisabled*(self: Service; roomId: string): bool =
  ## Ported from `is_disabled`.
  false

proc isBanned*(self: Service; roomId: string): bool =
  ## Ported from `is_banned`.
  false

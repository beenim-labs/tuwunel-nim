## directory/mod — service module.
##
## Ported from Rust service/rooms/directory/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/directory/mod.rs"
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

proc setPublic*(self: Service; roomId: string) =
  ## Ported from `set_public`.
  discard

proc setNotPublic*(self: Service; roomId: string) =
  ## Ported from `set_not_public`.
  discard

proc publicRooms*(self: Service): impl Stream<Item = string> + Send =
  ## Ported from `public_rooms`.
  discard

proc isPublicRoom*(self: Service; roomId: string): bool =
  ## Ported from `is_public_room`.
  false

proc visibility*(self: Service; roomId: string): Visibility =
  ## Ported from `visibility`.
  discard

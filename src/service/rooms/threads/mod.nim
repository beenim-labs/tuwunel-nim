## threads/mod — service module.
##
## Ported from Rust service/rooms/threads/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/threads/mod.rs"
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

proc updateParticipants*(self: Service; rootId: RawPduId; participants: [string]) =
  ## Ported from `update_participants`.
  discard

proc getParticipants*(self: Service; rootId: RawPduId): seq[string] =
  ## Ported from `get_participants`.
  @[]

proc deleteAllRoomsThreads*(self: Service; roomId: string) =
  ## Ported from `delete_all_rooms_threads`.
  discard

## event_handler/mod — service module.
##
## Ported from Rust service/rooms/event_handler/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/event_handler/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    mutexFederation*: RoomMutexMap

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc memoryUsage*(self: Service; out: mut (dyn Write + Send) =
  ## Ported from `memory_usage`.
  discard

proc clearCache*(self: Service) =
  ## Ported from `clear_cache`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc backOff*(self: Service; eventId: string) =
  ## Ported from `back_off`.
  discard

proc isBackedOff*(self: Service; eventId: string; range: Range<Duration>): bool =
  ## Ported from `is_backed_off`.
  false

proc eventExists*(self: Service; eventId: string): bool =
  ## Ported from `event_exists`.
  false

proc eventFetch*(self: Service; eventId: string): PduEvent =
  ## Ported from `event_fetch`.
  discard

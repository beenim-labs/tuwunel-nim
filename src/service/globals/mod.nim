## globals/mod — service module.
##
## Ported from Rust service/globals/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/globals/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    db*: Data
    serverUser*: string
    turnSecret*: Option[string]

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc waitPending*(self: Service): uint64 =
  ## Ported from `wait_pending`.
  0

proc waitCount*(self: Service; count: uint64): uint64 =
  ## Ported from `wait_count`.
  0

proc nextCount*(self: Service): data::Permit =
  ## Ported from `next_count`.
  discard

proc currentCount*(self: Service): uint64 =
  ## Ported from `current_count`.
  0

proc pendingCount*(self: Service): Range<uint64> =
  ## Ported from `pending_count`.
  discard

proc serverName*(self: Service): string =
  ## Ported from `server_name`.
  ""

proc userIsLocal*(self: Service; userId: string): bool =
  ## Ported from `user_is_local`.
  false

proc aliasIsLocal*(self: Service; alias: RoomAliasId): bool =
  ## Ported from `alias_is_local`.
  false

proc serverIsOurs*(self: Service; serverName: string): bool =
  ## Ported from `server_is_ours`.
  false

proc isReadOnly*(self: Service): bool =
  ## Ported from `is_read_only`.
  false

proc initRustlsProvider*(self: Service) =
  ## Ported from `init_rustls_provider`.
  discard

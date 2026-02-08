## auth_chain/mod — service module.
##
## Ported from Rust service/rooms/auth_chain/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/auth_chain/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    discard

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc clearCache*(self: Service) =
  ## Ported from `clear_cache`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc putCachedAuthChain*(self: Service; key: [Shortstring]; authChain: [Shortstring]) =
  ## Ported from `put_cached_auth_chain`.
  discard

proc getCachedAuthChain*(self: Service; key: [uint64]): seq[Shortstring] =
  ## Ported from `get_cached_auth_chain`.
  @[]

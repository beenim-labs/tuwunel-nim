## config/mod — service module.
##
## Ported from Rust service/config/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/config/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    discard

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc worker*(self: Service) =
  ## Ported from `worker`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc handleReload*(self: Service) =
  ## Ported from `handle_reload`.
  discard

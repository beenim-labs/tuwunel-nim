## membership/mod — service module.
##
## Ported from Rust service/membership/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/membership/mod.rs"
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

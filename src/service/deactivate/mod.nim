## deactivate/mod — service module.
##
## Ported from Rust service/deactivate/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/deactivate/mod.rs"
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

proc fullDeactivate*(self: Service; userId: string) =
  ## Ported from `full_deactivate`.
  discard

## emergency/mod — service module.
##
## Ported from Rust service/emergency/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/emergency/mod.rs"
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

proc setEmergencyAccess*(self: Service) =
  ## Ported from `set_emergency_access`.
  discard

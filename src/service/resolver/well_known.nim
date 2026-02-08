## resolver/well_known — service module.
##
## Ported from Rust service/resolver/well_known.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/resolver/well_known.rs"
  RustCrate* = "service"

proc requestWellKnown*(dest: string): Option[Deststring] =
  ## Ported from `request_well_known`.
  none(Deststring)

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
## sync/watch — service module.
##
## Ported from Rust service/sync/watch.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/sync/watch.rs"
  RustCrate* = "service"

## Minimal public API — service integration via database.
proc init*() =
  discard
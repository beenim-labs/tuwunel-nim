## timeline/redact — service module.
##
## Ported from Rust service/rooms/timeline/redact.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/timeline/redact.rs"
  RustCrate* = "service"

## Minimal public API — service integration via database.
proc init*() =
  discard
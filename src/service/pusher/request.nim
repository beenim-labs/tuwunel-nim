## pusher/request — service module.
##
## Ported from Rust service/pusher/request.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/pusher/request.rs"
  RustCrate* = "service"

## Minimal public API — service integration via database.
proc init*() =
  discard
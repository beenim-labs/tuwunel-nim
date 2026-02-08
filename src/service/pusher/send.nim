## pusher/send — service module.
##
## Ported from Rust service/pusher/send.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/pusher/send.rs"
  RustCrate* = "service"

## Minimal public API — service integration via database.
proc init*() =
  discard
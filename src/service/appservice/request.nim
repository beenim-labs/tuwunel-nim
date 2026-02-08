## appservice/request — service module.
##
## Ported from Rust service/appservice/request.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/appservice/request.rs"
  RustCrate* = "service"

## Minimal public API — service integration via database.
proc init*() =
  discard
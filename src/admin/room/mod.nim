## room/mod — admin module.
##
## Ported from Rust admin/room/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/room/mod.rs"
  RustCrate* = "admin"

type Service* = ref object
  ## room service.
  discard

proc init*() = discard
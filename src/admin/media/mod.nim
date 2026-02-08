## media/mod — admin module.
##
## Ported from Rust admin/media/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/media/mod.rs"
  RustCrate* = "admin"

type Service* = ref object
  ## media service.
  discard

proc init*() = discard
## server/mod — admin module.
##
## Ported from Rust admin/server/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/server/mod.rs"
  RustCrate* = "admin"

type Service* = ref object
  ## server service.
  discard

proc init*() = discard
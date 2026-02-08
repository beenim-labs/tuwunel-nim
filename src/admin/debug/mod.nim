## debug/mod — admin module.
##
## Ported from Rust admin/debug/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/debug/mod.rs"
  RustCrate* = "admin"

type Service* = ref object
  ## debug service.
  discard

proc init*() = discard
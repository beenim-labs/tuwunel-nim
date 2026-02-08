## token/mod — admin module.
##
## Ported from Rust admin/token/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/token/mod.rs"
  RustCrate* = "admin"

type Service* = ref object
  ## token service.
  discard

proc init*() = discard
## user/mod — admin module.
##
## Ported from Rust admin/user/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/user/mod.rs"
  RustCrate* = "admin"

type Service* = ref object
  ## user service.
  discard

proc init*() = discard
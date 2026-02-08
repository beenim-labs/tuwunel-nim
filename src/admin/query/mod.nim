## query/mod — admin module.
##
## Ported from Rust admin/query/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/query/mod.rs"
  RustCrate* = "admin"

type Service* = ref object
  ## query service.
  discard

proc init*() = discard
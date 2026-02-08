## check/mod — admin module.
##
## Ported from Rust admin/check/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/check/mod.rs"
  RustCrate* = "admin"

type Service* = ref object
  ## check service.
  discard

proc init*() = discard
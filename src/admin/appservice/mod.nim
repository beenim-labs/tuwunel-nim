## appservice/mod — admin module.
##
## Ported from Rust admin/appservice/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/appservice/mod.rs"
  RustCrate* = "admin"

type Service* = ref object
  ## appservice service.
  discard

proc init*() = discard
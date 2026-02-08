## server/mod — api module.
##
## Ported from Rust api/server/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/mod.rs"
  RustCrate* = "api"

type Service* = ref object
  ## server service.
  discard

proc init*() = discard
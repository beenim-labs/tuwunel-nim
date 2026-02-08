## client/mod — api module.
##
## Ported from Rust api/client/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/mod.rs"
  RustCrate* = "api"

type Service* = ref object
  ## client service.
  discard

proc init*() = discard
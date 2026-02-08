## room/mod — api module.
##
## Ported from Rust api/client/room/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/room/mod.rs"
  RustCrate* = "api"

type Service* = ref object
  ## room service.
  discard

proc init*() = discard
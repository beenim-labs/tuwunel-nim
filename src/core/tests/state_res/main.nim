## state_res/main — core module.
##
## Ported from Rust core/tests/state_res/main.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "core/tests/state_res/main.rs"
  RustCrate* = "core"

type Service* = ref object
  ## state_res service.
  discard

proc init*() = discard
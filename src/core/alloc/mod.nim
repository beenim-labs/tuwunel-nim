## alloc/mod — core module.
##
## Ported from Rust core/alloc/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "core/alloc/mod.rs"
  RustCrate* = "core"

type Service* = ref object
  ## alloc service.
  discard

# import ./je
# import ./default

proc init*() = discard
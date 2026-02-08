## mods/mod — core module.
##
## Ported from Rust core/mods/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "core/mods/mod.rs"
  RustCrate* = "core"

type Service* = ref object
  ## mods service.
  discard

# import ./canary
# import ./macros
# import ./module
# import ./new
# import ./path

proc init*() = discard
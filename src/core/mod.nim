## core/mod — core module.
##
## Ported from Rust core/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "core/mod.rs"
  RustCrate* = "core"

type Service* = ref object
  ## core service.
  discard

# import ./alloc
# import ./config
# import ./debug
# import ./error
# import ./info
# import ./log
# import ./matrix
# import ./metrics
# import ./mods
# import ./server
# import ./utils
# import ./mods

proc init*() = discard
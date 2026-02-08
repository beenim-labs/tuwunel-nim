## api/mod — api module.
##
## Ported from Rust api/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/mod.rs"
  RustCrate* = "api"

type Service* = ref object
  ## api service.
  discard

# import ./client
# import ./router
# import ./server

proc init*() = discard
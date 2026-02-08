## federation/mod — admin module.
##
## Ported from Rust admin/federation/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/federation/mod.rs"
  RustCrate* = "admin"

type Service* = ref object
  ## federation service.
  discard

proc init*() = discard
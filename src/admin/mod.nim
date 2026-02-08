## admin/mod — admin module.
##
## Ported from Rust admin/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/mod.rs"
  RustCrate* = "admin"

proc init*(adminService: tuwunel_service::admin::Service) =
  ## Ported from `init`.
  discard

proc fini*(adminService: tuwunel_service::admin::Service) =
  ## Ported from `fini`.
  discard

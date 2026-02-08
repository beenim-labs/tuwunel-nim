## admin/admin — admin module.
##
## Ported from Rust admin/admin.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/admin.rs"
  RustCrate* = "admin"

proc process*(command: AdminCommand; context: Context<'_>) =
  ## Ported from `process`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
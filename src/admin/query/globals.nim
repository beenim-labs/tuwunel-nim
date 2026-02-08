## query/globals — admin module.
##
## Ported from Rust admin/query/globals.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/query/globals.rs"
  RustCrate* = "admin"

proc process*(subcommand: GlobalsCommand; context: Context<'_>) =
  ## Ported from `process`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
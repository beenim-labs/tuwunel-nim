## query/sending — admin module.
##
## Ported from Rust admin/query/sending.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/query/sending.rs"
  RustCrate* = "admin"

proc process*(subcommand: SendingCommand; context: Context<'_>) =
  ## Ported from `process`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
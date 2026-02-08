## query/appservice — admin module.
##
## Ported from Rust admin/query/appservice.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/query/appservice.rs"
  RustCrate* = "admin"

proc process*(subcommand: AppserviceCommand; context: Context<'_>) =
  ## Ported from `process`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
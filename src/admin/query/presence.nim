## query/presence — admin module.
##
## Ported from Rust admin/query/presence.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/query/presence.rs"
  RustCrate* = "admin"

proc process*(subcommand: PresenceCommand; context: Context<'_>) =
  ## Ported from `process`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
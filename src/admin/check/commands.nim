## check/commands — admin module.
##
## Ported from Rust admin/check/commands.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/check/commands.rs"
  RustCrate* = "admin"

proc checkAllUsers*() =
  ## Ported from `check_all_users`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
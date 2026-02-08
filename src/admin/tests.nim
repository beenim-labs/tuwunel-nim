## admin/tests — admin module.
##
## Ported from Rust admin/tests.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/tests.rs"
  RustCrate* = "admin"

proc getHelpShort*() =
  ## Ported from `get_help_short`.
  discard

proc getHelpLong*() =
  ## Ported from `get_help_long`.
  discard

proc getHelpSubcommand*() =
  ## Ported from `get_help_subcommand`.
  discard

proc getHelpInner*(input: string) =
  ## Ported from `get_help_inner`.
  discard

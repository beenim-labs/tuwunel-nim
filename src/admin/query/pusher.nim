## query/pusher — admin module.
##
## Ported from Rust admin/query/pusher.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/query/pusher.rs"
  RustCrate* = "admin"

proc getPushers*(userId: string) =
  ## Ported from `get_pushers`.
  discard

proc removePusher*(userId: string; pushkey: string) =
  ## Ported from `remove_pusher`.
  discard

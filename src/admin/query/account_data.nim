## query/account_data — admin module.
##
## Ported from Rust admin/query/account_data.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/query/account_data.rs"
  RustCrate* = "admin"

proc changesSince*(userId: string; since: uint64; roomId: Option[string]) =
  ## Ported from `changes_since`.
  discard

proc accountDataGet*(userId: string; kind: string; roomId: Option[string]) =
  ## Ported from `account_data_get`.
  discard

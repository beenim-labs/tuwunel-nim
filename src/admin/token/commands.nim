## token/commands — admin module.
##
## Ported from Rust admin/token/commands.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/token/commands.rs"
  RustCrate* = "admin"

proc issue*(maxUses: Option[uint64]; maxAge: Option[string]; once: bool) =
  ## Ported from `issue`.
  discard

proc revoke*(token: string) =
  ## Ported from `revoke`.
  discard

proc list*() =
  ## Ported from `list`.
  discard

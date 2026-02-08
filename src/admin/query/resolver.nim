## query/resolver — admin module.
##
## Ported from Rust admin/query/resolver.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/query/resolver.rs"
  RustCrate* = "admin"

proc destinationsCache*(serverName: Option[string]) =
  ## Ported from `destinations_cache`.
  discard

proc overridesCache*(serverName: Option[string]) =
  ## Ported from `overrides_cache`.
  discard

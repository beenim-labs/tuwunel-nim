## query/sync — admin module.
##
## Ported from Rust admin/query/sync.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/query/sync.rs"
  RustCrate* = "admin"

proc listConnections*() =
  ## Ported from `list_connections`.
  discard

proc showConnection*(userId: string; deviceId: Option[OwnedDeviceId]; connId: Option[string]) =
  ## Ported from `show_connection`.
  discard

proc dropConnections*(userId: Option[string]; deviceId: Option[OwnedDeviceId]; connId: Option[string]) =
  ## Ported from `drop_connections`.
  discard

## client/well_known — api module.
##
## Ported from Rust api/client/well_known.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/well_known.rs"
  RustCrate* = "api"

proc wellKnownClient*() =
  ## Ported from `well_known_client`.
  discard

proc wellKnownSupport*() =
  ## Ported from `well_known_support`.
  discard

proc syncv3ClientServerJson*() =
  ## Ported from `syncv3_client_server_json`.
  discard

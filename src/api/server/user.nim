## server/user — api module.
##
## Ported from Rust api/server/user.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/user.rs"
  RustCrate* = "api"

proc getDevicesRoute*() =
  ## Ported from `get_devices_route`.
  discard

proc getKeysRoute*() =
  ## Ported from `get_keys_route`.
  discard

proc claimKeysRoute*() =
  ## Ported from `claim_keys_route`.
  discard

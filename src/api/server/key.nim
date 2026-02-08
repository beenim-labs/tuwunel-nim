## server/key — api module.
##
## Ported from Rust api/server/key.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/key.rs"
  RustCrate* = "api"

proc getServerKeysRoute*() =
  ## Ported from `get_server_keys_route`.
  discard

proc validUntilTs*(): MilliSecondsSinceUnixEpoch =
  ## Ported from `valid_until_ts`.
  discard

proc expiresTs*(): MilliSecondsSinceUnixEpoch =
  ## Ported from `expires_ts`.
  discard

proc getServerKeysDeprecatedRoute*() =
  ## Ported from `get_server_keys_deprecated_route`.
  discard

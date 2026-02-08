## extensions/account_data — api module.
##
## Ported from Rust api/client/sync/v5/extensions/account_data.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/sync/v5/extensions/account_data.rs"
  RustCrate* = "api"

proc collect*(syncInfo: SyncInfo<'_>; conn: Connection; window: Window): response::AccountData =
  ## Ported from `collect`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
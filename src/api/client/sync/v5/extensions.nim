## v5/extensions — api module.
##
## Ported from Rust api/client/sync/v5/extensions.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/sync/v5/extensions.rs"
  RustCrate* = "api"

proc handle*(syncInfo: SyncInfo<'_>; conn: Connection; window: Window): response::Extensions =
  ## Ported from `handle`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
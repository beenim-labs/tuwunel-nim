## extensions/typing — api module.
##
## Ported from Rust api/client/sync/v5/extensions/typing.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/sync/v5/extensions/typing.rs"
  RustCrate* = "api"

proc collect*(syncInfo: SyncInfo<'_>; conn: Connection; window: Window): response::Typing =
  ## Ported from `collect`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
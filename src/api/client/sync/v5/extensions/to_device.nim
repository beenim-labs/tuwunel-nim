## extensions/to_device — api module.
##
## Ported from Rust api/client/sync/v5/extensions/to_device.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/sync/v5/extensions/to_device.rs"
  RustCrate* = "api"

proc collect*(conn: Connection): Option[response::ToDevice] =
  ## Ported from `collect`.
  none(response::ToDevice)

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
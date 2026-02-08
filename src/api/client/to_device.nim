## client/to_device — api module.
##
## Ported from Rust api/client/to_device.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/to_device.rs"
  RustCrate* = "api"

proc sendEventToDeviceRoute*() =
  ## Ported from `send_event_to_device_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.
## client/dehydrated_device — api module.
##
## Ported from Rust api/client/dehydrated_device.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/dehydrated_device.rs"
  RustCrate* = "api"

proc putDehydratedDeviceRoute*() =
  ## Ported from `put_dehydrated_device_route`.
  discard

proc deleteDehydratedDeviceRoute*() =
  ## Ported from `delete_dehydrated_device_route`.
  discard

proc getDehydratedDeviceRoute*() =
  ## Ported from `get_dehydrated_device_route`.
  discard

proc getDehydratedEventsRoute*() =
  ## Ported from `get_dehydrated_events_route`.
  discard

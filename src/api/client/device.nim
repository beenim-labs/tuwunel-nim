## client/device — api module.
##
## Ported from Rust api/client/device.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/device.rs"
  RustCrate* = "api"

proc getDevicesRoute*() =
  ## Ported from `get_devices_route`.
  discard

proc getDeviceRoute*() =
  ## Ported from `get_device_route`.
  discard

proc updateDeviceRoute*() =
  ## Ported from `update_device_route`.
  discard

proc deleteDeviceRoute*() =
  ## Ported from `delete_device_route`.
  discard

proc deleteDevicesRoute*() =
  ## Ported from `delete_devices_route`.
  discard

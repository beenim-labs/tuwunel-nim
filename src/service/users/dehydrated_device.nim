## users/dehydrated_device — service module.
##
## Ported from Rust service/users/dehydrated_device.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/users/dehydrated_device.rs"
  RustCrate* = "service"

type
  DehydratedDevice* = ref object
    deviceId*: OwnedDeviceId
    deviceData*: Raw<DehydratedDeviceData>

proc setDehydratedDevice*(self: DehydratedDevice; userId: string; request: Request) =
  ## Ported from `set_dehydrated_device`.
  discard

proc removeDehydratedDevice*(self: DehydratedDevice; userId: string; maybeDeviceId: Option[DeviceId]): OwnedDeviceId =
  ## Ported from `remove_dehydrated_device`.
  discard

proc getDehydratedDeviceId*(self: DehydratedDevice; userId: string): OwnedDeviceId =
  ## Ported from `get_dehydrated_device_id`.
  discard

proc getDehydratedDevice*(self: DehydratedDevice; userId: string): DehydratedDevice =
  ## Ported from `get_dehydrated_device`.
  discard

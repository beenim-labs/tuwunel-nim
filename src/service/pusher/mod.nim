## pusher/mod — service module.
##
## Ported from Rust service/pusher/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/pusher/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    discard

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc setPusher*(self: Service; sender: string; senderDevice: DeviceId; pusher: set_pusher::v3::PusherAction) =
  ## Ported from `set_pusher`.
  discard

proc deletePusher*(self: Service; sender: string; pushkey: string) =
  ## Ported from `delete_pusher`.
  discard

proc getDevicePushkeys*(self: Service; sender: string; deviceId: DeviceId): seq[string] =
  ## Ported from `get_device_pushkeys`.
  @[]

proc getPusherDevice*(self: Service; pushkey: string): OwnedDeviceId =
  ## Ported from `get_pusher_device`.
  discard

proc getPusher*(self: Service; sender: string; pushkey: string): Pusher =
  ## Ported from `get_pusher`.
  discard

proc getPushers*(self: Service; sender: string): seq[Pusher] =
  ## Ported from `get_pushers`.
  @[]

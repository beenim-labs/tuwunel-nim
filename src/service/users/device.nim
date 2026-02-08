## users/device — service module.
##
## Ported from Rust service/users/device.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/users/device.rs"
  RustCrate* = "service"

proc createDevice*(userId: string; deviceId: Option[DeviceId]) =
  ## Ported from `create_device`.
  discard

proc removeDevice*(userId: string; deviceId: DeviceId) =
  ## Ported from `remove_device`.
  discard

proc findFromToken*(token: string): (string)> =
  ## Ported from `find_from_token`.
  discard

proc removeTokens*(userId: string; deviceId: DeviceId) =
  ## Ported from `remove_tokens`.
  discard

proc setAccessToken*(userId: string; deviceId: DeviceId; accessToken: string; expiresIn: Option[Duration]; refreshToken: Option[string]) =
  ## Ported from `set_access_token`.
  discard

proc removeAccessToken*(userId: string; deviceId: DeviceId) =
  ## Ported from `remove_access_token`.
  discard

proc getAccessToken*(userId: string; deviceId: DeviceId): string =
  ## Ported from `get_access_token`.
  ""

proc generateAccessToken*(expires: bool): (string, Option[Duration]) =
  ## Ported from `generate_access_token`.
  discard

proc setRefreshToken*(userId: string; deviceId: DeviceId; refreshToken: string) =
  ## Ported from `set_refresh_token`.
  discard

proc removeRefreshToken*(userId: string; deviceId: DeviceId) =
  ## Ported from `remove_refresh_token`.
  discard

proc getRefreshToken*(userId: string; deviceId: DeviceId): string =
  ## Ported from `get_refresh_token`.
  ""

proc generateRefreshToken*(): string =
  ## Ported from `generate_refresh_token`.
  ""

proc addToDeviceEvent*(sender: string; targetUserId: string; targetDeviceId: DeviceId; eventType: string; content: serde_json::Value) =
  ## Ported from `add_to_device_event`.
  discard

proc updateDeviceLastSeen*(userId: string; deviceId: DeviceId; lastSeen: Option[MilliSecondsSinceUnixEpoch]) =
  ## Ported from `update_device_last_seen`.
  discard

proc putDeviceMetadata*(userId: string; notify: bool; device: Device) =
  ## Ported from `put_device_metadata`.
  discard

proc getDeviceMetadata*(userId: string; deviceId: DeviceId): Device =
  ## Ported from `get_device_metadata`.
  discard

proc deviceExists*(userId: string; deviceId: DeviceId): bool =
  ## Ported from `device_exists`.
  false

proc getDevicelistVersion*(userId: string): uint64 =
  ## Ported from `get_devicelist_version`.
  0

proc increment*(db: Map; key: [u8]) =
  ## Ported from `increment`.
  discard

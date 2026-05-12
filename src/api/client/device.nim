const
  RustPath* = "api/client/device.rs"
  RustCrate* = "api"

import std/json

type
  DevicePolicyResult* = tuple[ok: bool, errcode: string, message: string]

  DeviceData* = object
    deviceId*: string
    displayName*: string
    lastSeenIp*: string
    lastSeenTs*: int64

proc devicePayload*(device: DeviceData): JsonNode =
  result = %*{"device_id": device.deviceId}
  if device.displayName.len > 0:
    result["display_name"] = %device.displayName
  if device.lastSeenIp.len > 0:
    result["last_seen_ip"] = %device.lastSeenIp
  if device.lastSeenTs > 0:
    result["last_seen_ts"] = %device.lastSeenTs

proc devicesPayload*(devices: openArray[DeviceData]): JsonNode =
  var arr = newJArray()
  for device in devices:
    arr.add(devicePayload(device))
  %*{"devices": arr}

proc deviceUpdateFromBody*(body: JsonNode): tuple[ok: bool, updateDisplayName: bool, displayName: string, errcode: string, message: string] =
  if body.isNil or body.kind != JObject:
    return (false, false, "", "M_BAD_JSON", "Invalid JSON body.")
  if body.hasKey("display_name"):
    if body["display_name"].kind == JString:
      return (true, true, body["display_name"].getStr(""), "", "")
    if body["display_name"].kind == JNull:
      return (true, true, "", "", "")
    return (false, false, "", "M_BAD_JSON", "display_name must be a string or null.")
  (true, false, "", "", "")

proc deleteDevicesFromBody*(body: JsonNode): tuple[ok: bool, deviceIds: seq[string], errcode: string, message: string] =
  if body.isNil or body.kind != JObject:
    return (false, @[], "M_BAD_JSON", "Invalid JSON body.")
  if body{"devices"}.kind != JArray:
    return (false, @[], "M_BAD_JSON", "devices must be an array.")
  result = (true, @[], "", "")
  for deviceNode in body["devices"]:
    let deviceId = deviceNode.getStr("")
    if deviceId.len > 0:
      result.deviceIds.add(deviceId)

proc deviceNotFound*(): DevicePolicyResult =
  (false, "M_NOT_FOUND", "Device not found.")

proc deviceWriteResponse*(): JsonNode =
  newJObject()

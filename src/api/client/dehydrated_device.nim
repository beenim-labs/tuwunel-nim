const
  RustPath* = "api/client/dehydrated_device.rs"
  RustCrate* = "api"
  MaxBatchEvents* = 50

import std/json

type
  DehydratedDeviceData* = object
    deviceId*: string
    deviceData*: JsonNode

proc deviceDataFromBody*(body: JsonNode; fallbackDeviceId = ""): tuple[ok: bool, device: DehydratedDeviceData, errcode: string, message: string] =
  if body.isNil or body.kind != JObject:
    return (false, DehydratedDeviceData(), "M_BAD_JSON", "Invalid dehydrated device payload.")
  let deviceId = body{"device_id"}.getStr(fallbackDeviceId)
  (true, DehydratedDeviceData(
    deviceId: deviceId,
    deviceData: if body.hasKey("device_data"): body["device_data"].copy() else: newJObject(),
  ), "", "")

proc dehydratedDevicePayload*(device: DehydratedDeviceData): JsonNode =
  %*{
    "device_id": device.deviceId,
    "device_data": if device.deviceData.isNil: newJObject() else: device.deviceData.copy(),
  }

proc putDehydratedDeviceResponse*(deviceId: string): JsonNode =
  %*{"device_id": deviceId}

proc deleteDehydratedDeviceResponse*(deviceId = ""): JsonNode =
  if deviceId.len > 0:
    %*{"device_id": deviceId}
  else:
    newJObject()

proc dehydratedEventsResponse*(events: openArray[JsonNode]; nextBatch = ""): JsonNode =
  var arr = newJArray()
  for event in events:
    arr.add(if event.isNil: newJObject() else: event.copy())
  result = %*{"events": arr}
  if nextBatch.len > 0:
    result["next_batch"] = %nextBatch
  else:
    result["next_batch"] = %""

proc dehydratedEventsResponse*(nextBatch = ""): JsonNode =
  let empty: seq[JsonNode] = @[]
  dehydratedEventsResponse(empty, nextBatch)

proc dehydratedNotFoundMessage*(): string =
  "No dehydrated device is stored."

const
  RustPath* = "api/client/sync/v5/extensions/to_device.rs"
  RustCrate* = "api"

import std/[json, strutils]

proc toDeviceSince*(requestSince: string; globalSince, nextBatch: uint64): uint64 =
  var parsed = globalSince
  if requestSince.len > 0:
    try:
      parsed = parseUInt(requestSince)
    except ValueError:
      parsed = globalSince
  min(parsed, nextBatch)

proc toDevicePayload*(
  nextBatch: uint64;
  events: openArray[JsonNode]
): JsonNode =
  result = %*{
    "next_batch": $nextBatch,
    "events": []
  }
  for event in events:
    result["events"].add(if event.isNil: newJObject() else: event.copy())

proc optionalToDevicePayload*(
  nextBatch: uint64;
  events: openArray[JsonNode]
): JsonNode =
  if events.len == 0:
    newJNull()
  else:
    toDevicePayload(nextBatch, events)

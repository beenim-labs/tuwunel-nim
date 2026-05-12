const
  RustPath* = "api/client/to_device.rs"
  RustCrate* = "api"

import std/[algorithm, json]

type
  ToDevicePolicyResult* = tuple[ok: bool, errcode: string, message: string]

  ToDeviceMessage* = object
    targetUserId*: string
    targetDeviceId*: string
    content*: JsonNode

proc toDeviceTxnKey*(sender, deviceId, txnId: string): string =
  sender & "\x1f" & deviceId & "\x1f" & txnId

proc toDevicePolicy*(eventType, txnId: string; body: JsonNode): ToDevicePolicyResult =
  if eventType.len == 0:
    return (false, "M_INVALID_PARAM", "Event type is required.")
  if txnId.len == 0:
    return (false, "M_INVALID_PARAM", "Transaction id is required.")
  if body.isNil or body.kind != JObject:
    return (false, "M_BAD_JSON", "Invalid JSON body.")
  let messages = body{"messages"}
  if messages.isNil or messages.kind != JObject:
    return (false, "M_BAD_JSON", "messages must be an object.")
  for targetUserId, deviceMap in messages:
    if targetUserId.len == 0 or deviceMap.kind != JObject:
      return (false, "M_BAD_JSON", "messages must map user ids to device maps.")
    for rawDeviceId, _ in deviceMap:
      if rawDeviceId.len == 0:
        return (false, "M_BAD_JSON", "Device id is required.")
  (true, "", "")

proc extractToDeviceMessages*(body: JsonNode): tuple[ok: bool, errcode: string, message: string, events: seq[ToDeviceMessage]] =
  let policy = toDevicePolicy("m.dummy", "txn", body)
  if not policy.ok:
    return (false, policy.errcode, policy.message, @[])
  result = (true, "", "", @[])
  for targetUserId, deviceMap in body["messages"]:
    for rawDeviceId, content in deviceMap:
      result.events.add(ToDeviceMessage(
        targetUserId: targetUserId,
        targetDeviceId: rawDeviceId,
        content: if content.isNil: newJNull() else: content.copy(),
      ))

proc targetDeviceIds*(rawDeviceId: string; knownDeviceIds: openArray[string]): seq[string] =
  result = @[]
  if rawDeviceId == "*":
    for deviceId in knownDeviceIds:
      if deviceId.len > 0:
        result.add(deviceId)
    result.sort(system.cmp[string])
  elif rawDeviceId.len > 0:
    result.add(rawDeviceId)

proc toDeviceEvent*(eventType, sender: string; content: JsonNode): JsonNode =
  %*{
    "type": eventType,
    "sender": sender,
    "content": if content.isNil: newJObject() else: content.copy(),
  }

proc toDeviceResponse*(): JsonNode =
  newJObject()

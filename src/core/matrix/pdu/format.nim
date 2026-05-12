const
  RustPath* = "core/matrix/pdu/format.rs"
  RustCrate* = "core"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/[json, strutils]

proc roomVersionRequiresEventId*(roomVersion: string): bool =
  roomVersion in ["1", "2"]

proc roomVersionUsesLegacyRefs*(roomVersion: string): bool =
  roomVersion in ["1", "2"]

proc roomVersionRequiresCreateRoomId*(roomVersion: string): bool =
  try:
    parseInt(roomVersion) <= 10
  except ValueError:
    false

proc mutateOutgoingReferenceFormat(value: JsonNode): JsonNode =
  result = newJArray()
  if value.kind != JArray:
    return value.copy()
  for item in value:
    let eventId = item.getStr("")
    if eventId.len == 0:
      result.add(item.copy())
    else:
      result.add(%*[eventId, {"": ""}])

proc mutateIncomingReferenceFormat(value: JsonNode): JsonNode =
  result = newJArray()
  if value.kind != JArray:
    return value.copy()
  for item in value:
    if item.kind == JArray and item.len > 0:
      result.add(%item[0].getStr(""))
    else:
      result.add(item.copy())

proc intoOutgoingFederation*(pduJson: JsonNode; roomVersion: string): JsonNode =
  result = if pduJson.isNil: newJObject() else: pduJson.copy()
  if result.kind != JObject:
    return newJObject()

  if result{"unsigned"}.kind == JObject:
    result["unsigned"].delete("transaction_id")

  if not roomVersionRequiresEventId(roomVersion):
    result.delete("event_id")

  if not roomVersionRequiresCreateRoomId(roomVersion) and result{"type"}.getStr("") == "m.room.create":
    result.delete("room_id")

  if roomVersionUsesLegacyRefs(roomVersion):
    if result{"auth_events"}.kind == JArray:
      result["auth_events"] = mutateOutgoingReferenceFormat(result["auth_events"])
    if result{"prev_events"}.kind == JArray:
      result["prev_events"] = mutateOutgoingReferenceFormat(result["prev_events"])

proc fromIncomingFederation*(
    roomId, eventId: string;
    pduJson: JsonNode;
    roomVersion: string
): JsonNode =
  result = if pduJson.isNil: newJObject() else: pduJson.copy()
  if result.kind != JObject:
    return newJObject()

  if roomVersionUsesLegacyRefs(roomVersion):
    if result{"auth_events"}.kind == JArray:
      result["auth_events"] = mutateIncomingReferenceFormat(result["auth_events"])
    if result{"prev_events"}.kind == JArray:
      result["prev_events"] = mutateIncomingReferenceFormat(result["prev_events"])

  if not roomVersionRequiresCreateRoomId(roomVersion) and result{"type"}.getStr("") == "m.room.create":
    result["room_id"] = %roomId

  if not roomVersionRequiresEventId(roomVersion):
    result["event_id"] = %eventId

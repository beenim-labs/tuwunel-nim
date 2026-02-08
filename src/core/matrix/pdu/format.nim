## PDU format conversion — federation PDU normalization.
##
## Ported from Rust core/matrix/pdu/format.rs — handles converting
## PDU JSON between outgoing federation format, incoming federation
## format, and internal format. Handles room-version-specific
## differences in event_id handling and reference format.

import std/[json, options]
import ../event

const
  RustPath* = "core/matrix/pdu/format.rs"
  RustCrate* = "core"

proc isReferenceFormatV1*(roomVersion: RoomVersionId): bool =
  ## Check if the room version uses reference format v1.
  ## V1/V2 rooms use [event_id, {}] pairs for auth/prev events.
  case roomVersion
  of "1", "2": true
  else: false

proc requiresRoomCreateRoomId*(roomVersion: RoomVersionId): bool =
  ## Whether the room version requires room_id in m.room.create events.
  case roomVersion
  of "1", "2", "3", "4", "5", "6", "7", "8", "9", "10": true
  else: false # v11+ don't require room_id in m.room.create

proc mutateOutgoingReferenceFormat*(arr: var JsonNode) =
  ## Convert event reference arrays from flat string format to v1 format.
  ## ["$eventId"] -> [["$eventId", {}]]
  if arr.kind != JArray:
    return
  var newArr = newJArray()
  for item in arr:
    if item.kind == JString:
      newArr.add(%*[item.getStr(), newJObject()])
    else:
      newArr.add(item)
  arr = newArr

proc mutateIncomingReferenceFormat*(arr: var JsonNode) =
  ## Convert event reference arrays from v1 format to flat string format.
  ## [["$eventId", {}]] -> ["$eventId"]
  if arr.kind != JArray:
    return
  var newArr = newJArray()
  for item in arr:
    if item.kind == JArray and item.len > 0 and item[0].kind == JString:
      newArr.add(item[0])
    elif item.kind == JString:
      newArr.add(item)
  arr = newArr

proc intoOutgoingFederation*(pduJson: var JsonNode;
                              roomVersion: RoomVersionId) =
  ## Convert a PDU to outgoing federation format.
  ##
  ## - Removes transaction_id from unsigned
  ## - Removes event_id for v3+ rooms
  ## - Removes room_id from m.room.create for v11+ rooms
  ## - Converts auth_events/prev_events to reference format v1 for v1/v2
  if pduJson.kind != JObject:
    return

  # Remove transaction_id from unsigned
  if pduJson.hasKey("unsigned") and pduJson["unsigned"].kind == JObject:
    if pduJson["unsigned"].hasKey("transaction_id"):
      pduJson["unsigned"].delete("transaction_id")

  let requireEventId = case roomVersion
    of "1", "2": true
    else: false

  if not requireEventId and pduJson.hasKey("event_id"):
    pduJson.delete("event_id")

  # Remove room_id from m.room.create for v11+
  if not requiresRoomCreateRoomId(roomVersion):
    if pduJson.hasKey("type") and pduJson["type"].getStr("") == "m.room.create":
      if pduJson.hasKey("room_id"):
        pduJson.delete("room_id")

  # Convert reference format for v1/v2
  if isReferenceFormatV1(roomVersion):
    if pduJson.hasKey("auth_events"):
      var ae = pduJson["auth_events"]
      mutateOutgoingReferenceFormat(ae)
      pduJson["auth_events"] = ae
    if pduJson.hasKey("prev_events"):
      var pe = pduJson["prev_events"]
      mutateOutgoingReferenceFormat(pe)
      pduJson["prev_events"] = pe

proc fromIncomingFederation*(roomId: string; eventId: string;
                              pduJson: var JsonNode;
                              roomVersion: RoomVersionId) =
  ## Convert incoming federation PDU to internal format.
  ##
  ## - Converts reference format v1 to flat format
  ## - Inserts room_id for v11+ m.room.create
  ## - Inserts event_id for v3+ rooms
  if pduJson.kind != JObject:
    return

  if isReferenceFormatV1(roomVersion):
    if pduJson.hasKey("auth_events"):
      var ae = pduJson["auth_events"]
      mutateIncomingReferenceFormat(ae)
      pduJson["auth_events"] = ae
    if pduJson.hasKey("prev_events"):
      var pe = pduJson["prev_events"]
      mutateIncomingReferenceFormat(pe)
      pduJson["prev_events"] = pe

  # Insert room_id for v11+ m.room.create
  if not requiresRoomCreateRoomId(roomVersion):
    if pduJson.hasKey("type") and pduJson["type"].getStr("") == "m.room.create":
      pduJson["room_id"] = %roomId

  let requireEventId = case roomVersion
    of "1", "2": true
    else: false

  if not requireEventId:
    pduJson["event_id"] = %eventId

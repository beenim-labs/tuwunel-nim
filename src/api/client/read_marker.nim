const
  RustPath* = "api/client/read_marker.rs"
  RustCrate* = "api"

import std/json

type
  ReadMarkerPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc readMarkerResponse*(): JsonNode =
  newJObject()

proc fullyReadContent*(eventId: string): JsonNode =
  %*{"event_id": eventId}

proc receiptContent*(
  eventId, receiptType, userId: string;
  ts: int64;
  threadId = "";
): JsonNode =
  var userEntry = %*{"ts": ts}
  if threadId.len > 0:
    userEntry["thread_id"] = %threadId
  var users = newJObject()
  users[userId] = userEntry
  var receiptTypes = newJObject()
  receiptTypes[receiptType] = users
  result = newJObject()
  result[eventId] = receiptTypes

proc receiptEvent*(roomId, eventId, receiptType, userId: string; ts: int64; threadId = ""): JsonNode =
  %*{
    "type": "m.receipt",
    "room_id": roomId,
    "content": receiptContent(eventId, receiptType, userId, ts, threadId)
  }

proc receiptPolicy*(
  receiptType: string;
  threadId = "";
  eventRelatedToThread = true;
): ReadMarkerPolicyResult =
  if receiptType == "m.fully_read" and threadId.len > 0:
    return (false, "M_INVALID_PARAM", "thread_id must not be set for m.fully_read receipts")
  if receiptType notin ["m.fully_read", "m.read", "m.read.private"]:
    return (false, "M_INVALID_PARAM", "Unsupported receipt type.")
  if not eventRelatedToThread:
    return (false, "M_INVALID_PARAM", "event_id is not related to the given thread_id")
  (true, "", "")

proc readMarkersFromBody*(body: JsonNode): tuple[fullyRead: string, publicRead: string, privateRead: string] =
  result = ("", "", "")
  if body.isNil or body.kind != JObject:
    return
  result.fullyRead = body{"m.fully_read"}.getStr(body{"fully_read"}.getStr(""))
  result.publicRead = body{"m.read"}.getStr(body{"read_receipt"}.getStr(""))
  result.privateRead = body{"m.read.private"}.getStr(body{"private_read_receipt"}.getStr(""))

proc readMarkerBodyPolicy*(markers: tuple[fullyRead: string, publicRead: string, privateRead: string]): ReadMarkerPolicyResult =
  if markers.fullyRead.len == 0 and markers.publicRead.len == 0 and markers.privateRead.len == 0:
    return (false, "M_BAD_JSON", "No read marker or receipt event id supplied.")
  (true, "", "")

const
  RustPath* = "api/client/send.rs"
  RustCrate* = "api"

import std/json

type
  SendPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc sendResponse*(eventId: string): JsonNode =
  %*{"event_id": eventId}

proc redactsFromSendContent*(eventType: string; content: JsonNode): string =
  if eventType != "m.room.redaction" or content.isNil or content.kind != JObject:
    return ""
  content{"redacts"}.getStr("")

proc sendAccessPolicy*(
  roomExists, canSend: bool;
  eventType = "";
  encryptionAllowed = true;
  redactionsAllowed = true;
): SendPolicyResult =
  if not roomExists:
    return (false, "M_NOT_FOUND", "Room not found.")
  if not canSend:
    return (false, "M_FORBIDDEN", "You are not joined to this room.")
  if eventType == "m.room.encrypted" and not encryptionAllowed:
    return (false, "M_FORBIDDEN", "Encryption has been disabled")
  if eventType == "m.room.redaction" and not redactionsAllowed:
    return (false, "M_FORBIDDEN", "Redactions are disabled on this server.")
  (true, "", "")

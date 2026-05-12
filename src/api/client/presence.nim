const
  RustPath* = "api/client/presence.rs"
  RustCrate* = "api"

import std/json

type
  PresencePolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc isValidPresenceValue*(value: string): bool =
  value in ["online", "offline", "unavailable", "busy"]

proc presenceSetPolicy*(
  allowLocalPresence: bool;
  senderMatchesTarget: bool;
  isAppservice = false;
): PresencePolicyResult =
  if not allowLocalPresence:
    return (false, "M_FORBIDDEN", "Presence is disabled on this server.")
  if not senderMatchesTarget and not isAppservice:
    return (false, "M_INVALID_PARAM", "Not allowed to set presence of other users.")
  (true, "", "")

proc presenceGetPolicy*(
  allowLocalPresence: bool;
  visible: bool;
  found: bool;
): PresencePolicyResult =
  if not allowLocalPresence:
    return (false, "M_FORBIDDEN", "Presence is disabled on this server.")
  if not visible or not found:
    return (false, "M_NOT_FOUND", "Presence state for this user was not found.")
  (true, "", "")

proc presenceEvent*(
  sender, presenceValue: string;
  currentlyActive: bool;
  lastActiveAgo: int64;
  statusMsg = "";
  displayName = "";
  avatarUrl = "";
): JsonNode =
  var content = %*{
    "presence": presenceValue,
    "currently_active": currentlyActive,
    "last_active_ago": lastActiveAgo,
  }
  if statusMsg.len > 0:
    content["status_msg"] = %statusMsg
  if displayName.len > 0:
    content["displayname"] = %displayName
  if avatarUrl.len > 0:
    content["avatar_url"] = %avatarUrl
  %*{
    "sender": sender,
    "type": "m.presence",
    "content": content,
  }

proc presenceResponse*(
  presenceValue: string;
  currentlyActive: bool;
  lastActiveAgo: int64;
  statusMsg = "";
): JsonNode =
  result = %*{
    "presence": presenceValue,
    "currently_active": currentlyActive,
  }
  if not currentlyActive:
    result["last_active_ago"] = %lastActiveAgo
  if statusMsg.len > 0:
    result["status_msg"] = %statusMsg

proc presenceWriteResponse*(): JsonNode =
  newJObject()

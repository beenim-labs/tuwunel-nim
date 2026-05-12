const
  RustPath* = "api/client/tag.rs"
  RustCrate* = "api"

import std/json

type
  TagPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc tagAccessPolicy*(
  senderUser, targetUser: string;
  joinedRoom: bool;
  isAppservice = false;
): TagPolicyResult =
  if senderUser != targetUser and not isAppservice:
    return (false, "M_FORBIDDEN", "You cannot access tags for this room.")
  if not joinedRoom:
    return (false, "M_FORBIDDEN", "You cannot access tags for this room.")
  (true, "", "")

proc tagsPayload*(content: JsonNode = nil): JsonNode =
  if not content.isNil and content.kind == JObject:
    result = content.copy()
  else:
    result = newJObject()
  if not result.hasKey("tags") or result["tags"].kind != JObject:
    result["tags"] = newJObject()

proc updateTagPayload*(existing: JsonNode; tag: string; tagContent: JsonNode): JsonNode =
  result = tagsPayload(existing)
  result["tags"][tag] = if tagContent.isNil: newJObject() else: tagContent.copy()

proc deleteTagPayload*(existing: JsonNode; tag: string): JsonNode =
  result = tagsPayload(existing)
  result["tags"].delete(tag)

proc tagWriteResponse*(): JsonNode =
  newJObject()

const
  RustPath* = "api/client/account_data.rs"
  RustCrate* = "api"

import std/json

type
  AccountDataPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc accountDataAccessPolicy*(
  senderUser, targetUser: string;
  isAppservice = false;
): AccountDataPolicyResult =
  if senderUser != targetUser and not isAppservice:
    return (false, "M_FORBIDDEN", "You cannot access account data for other users.")
  (true, "", "")

proc isEmptyObjectJson*(node: JsonNode): bool =
  node.isNil or (node.kind == JObject and node.len == 0)

proc accountDataEventJson*(eventType: string; content: JsonNode): JsonNode =
  %*{
    "type": eventType,
    "content": if content.isNil: newJObject() else: content.copy()
  }

proc accountDataSetPolicy*(eventType: string): AccountDataPolicyResult =
  if eventType == "m.fully_read":
    return (
      false,
      "M_BAD_JSON",
      "This endpoint cannot be used for marking a room as fully read (setting m.fully_read)",
    )
  if eventType == "m.push_rules":
    return (
      false,
      "M_BAD_JSON",
      "This endpoint cannot be used for setting/configuring push rules.",
    )
  (true, "", "")

proc accountDataGetPolicy*(content: JsonNode): AccountDataPolicyResult =
  if isEmptyObjectJson(content):
    return (false, "M_NOT_FOUND", "Data not found.")
  (true, "", "")

proc accountDataResponse*(content: JsonNode): JsonNode =
  if content.isNil: newJObject() else: content.copy()

proc accountDataWriteResponse*(): JsonNode =
  newJObject()

proc isEmptyAccountDataEvent*(event: JsonNode): bool =
  if event.isNil or event.kind != JObject:
    return true
  isEmptyObjectJson(event{"content"})

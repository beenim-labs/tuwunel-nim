const
  RustPath* = "api/client/sync/v5/extensions/typing.rs"
  RustCrate* = "api"

import std/[json, tables]

proc typingEvent*(userIds: openArray[string]): JsonNode =
  result = %*{
    "type": "m.typing",
    "content": {
      "user_ids": []
    }
  }
  for userId in userIds:
    result["content"]["user_ids"].add(%userId)

proc typingPayload*(
  rooms: Table[string, seq[string]] = initTable[string, seq[string]]()
): JsonNode =
  result = %*{"rooms": {}}
  for roomId, userIds in rooms:
    if userIds.len > 0:
      result["rooms"][roomId] = typingEvent(userIds)

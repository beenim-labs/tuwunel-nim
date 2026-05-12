const
  RustPath* = "api/client/typing.rs"
  RustCrate* = "api"

import std/json

type
  TypingPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc typingPolicy*(
  senderMatchesTarget: bool;
  senderJoinedRoom: bool;
  isAppservice = false;
): TypingPolicyResult =
  if not senderMatchesTarget and not isAppservice:
    return (false, "M_FORBIDDEN", "You cannot update typing status of other users.")
  if not senderJoinedRoom:
    return (false, "M_FORBIDDEN", "You are not in this room.")
  (true, "", "")

proc clampTypingTimeout*(timeoutMs: int64; minMs = 1000'i64; maxMs = 300000'i64): int64 =
  if timeoutMs < minMs:
    minMs
  elif timeoutMs > maxMs:
    maxMs
  else:
    timeoutMs

proc typingEvent*(userIds: openArray[string]): JsonNode =
  var ids = newJArray()
  for userId in userIds:
    ids.add(%userId)
  %*{
    "type": "m.typing",
    "content": {
      "user_ids": ids
    }
  }

proc typingResponse*(): JsonNode =
  newJObject()

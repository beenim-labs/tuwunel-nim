const
  RustPath* = "api/client/unstable.rs"
  RustCrate* = "api"

import std/json

type
  UnstablePolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc mutualRoomsPolicy*(requesterUserId, targetUserId: string): UnstablePolicyResult =
  if requesterUserId == targetUserId:
    return (false, "M_UNKNOWN", "You cannot request rooms in common with yourself.")
  (true, "", "")

proc mutualRoomsResponse*(joined: JsonNode; nextBatchToken: JsonNode = newJNull()): JsonNode =
  %*{
    "joined": if joined.isNil: newJArray() else: joined.copy(),
    "next_batch_token": if nextBatchToken.isNil: newJNull() else: nextBatchToken.copy(),
  }

proc profileFieldWriteResponse*(): JsonNode =
  newJObject()

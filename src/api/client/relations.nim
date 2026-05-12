const
  RustPath* = "api/client/relations.rs"
  RustCrate* = "api"
  LimitDefault* = 30
  LimitMax* = 100

import std/json

type
  RelationsPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc relationsLimit*(raw: int): int =
  if raw <= 0:
    LimitDefault
  else:
    min(raw, LimitMax)

proc relationsPolicy*(roomExists, canViewRoom, targetInRoom: bool): RelationsPolicyResult =
  if not roomExists:
    return (false, "M_NOT_FOUND", "Event not found in room.")
  if not canViewRoom:
    return (false, "M_FORBIDDEN", "You cannot view this room.")
  if not targetInRoom:
    return (false, "M_NOT_FOUND", "Event not found in room.")
  (true, "", "")

proc relationsResponse*(
  chunk: JsonNode;
  nextBatch = "";
  prevBatch = "";
  recursionDepth: int = -1;
): JsonNode =
  result = %*{
    "chunk": if chunk.isNil: newJArray() else: chunk.copy(),
    "next_batch": nextBatch,
    "prev_batch": prevBatch,
  }
  if recursionDepth >= 0:
    result["recursion_depth"] = %recursionDepth

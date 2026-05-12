const
  RustPath* = "api/client/threads.rs"
  RustCrate* = "api"
  LimitDefault* = 10
  LimitMax* = 100

import std/json

type
  ThreadsPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc threadsLimit*(raw: int): int =
  if raw <= 0:
    LimitDefault
  else:
    min(raw, LimitMax)

proc threadsPolicy*(roomExists, canViewRoom: bool): ThreadsPolicyResult =
  if not roomExists:
    return (false, "M_NOT_FOUND", "Room not found.")
  if not canViewRoom:
    return (false, "M_FORBIDDEN", "You cannot view this room.")
  (true, "", "")

proc threadsResponse*(chunk: JsonNode; nextBatch = ""): JsonNode =
  %*{
    "chunk": if chunk.isNil: newJArray() else: chunk.copy(),
    "next_batch": nextBatch,
  }

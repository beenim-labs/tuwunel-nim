const
  RustPath* = "api/client/message.rs"
  RustCrate* = "api"
  LimitDefault* = 10
  LimitMax* = 1000

import std/json

type
  MessagePolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc messageLimit*(raw: int): int =
  if raw <= 0:
    LimitDefault
  else:
    min(raw, LimitMax)

proc normalizeDirection*(dir: string): tuple[ok: bool, backwards: bool, errcode: string, message: string] =
  case dir
  of "", "b":
    (true, true, "", "")
  of "f":
    (true, false, "", "")
  else:
    (false, true, "M_INVALID_PARAM", "dir must be 'b' or 'f'.")

proc messageAccessPolicy*(roomExists, canViewRoom: bool): MessagePolicyResult =
  if not roomExists:
    return (false, "M_NOT_FOUND", "Room not found.")
  if not canViewRoom:
    return (false, "M_FORBIDDEN", "You don't have permission to view this room.")
  (true, "", "")

proc messagesResponse*(chunk: JsonNode; start = ""; ending = ""; state: JsonNode = nil): JsonNode =
  result = %*{
    "chunk": if chunk.isNil: newJArray() else: chunk.copy(),
    "start": start,
    "end": ending,
  }
  if not state.isNil:
    result["state"] = state.copy()

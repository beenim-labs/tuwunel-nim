const
  RustPath* = "api/client/room/initial_sync.rs"
  RustCrate* = "api"
  LimitMax* = 50

import std/json

type
  InitialSyncPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc initialSyncLimit*(raw: int): int =
  max(0, min(raw, LimitMax))

proc initialSyncPolicy*(roomExists, canViewRoom: bool): InitialSyncPolicyResult =
  if not roomExists:
    return (false, "M_NOT_FOUND", "Room not found.")
  if not canViewRoom:
    return (false, "M_FORBIDDEN", "No room preview available.")
  (true, "", "")

proc messagesChunk*(chunk: JsonNode; start = ""; ending = ""): JsonNode =
  %*{
    "chunk": if chunk.isNil: newJArray() else: chunk.copy(),
    "start": start,
    "end": ending,
  }

proc initialSyncResponse*(
  roomId, membership, visibility: string;
  messages, state, accountData: JsonNode;
): JsonNode =
  %*{
    "room_id": roomId,
    "membership": membership,
    "visibility": visibility,
    "messages": if messages.isNil: messagesChunk(newJArray()) else: messages.copy(),
    "state": if state.isNil: newJArray() else: state.copy(),
    "account_data": if accountData.isNil: newJArray() else: accountData.copy(),
    "presence": [],
  }

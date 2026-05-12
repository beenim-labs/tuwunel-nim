const
  RustPath* = "api/client/room/create.rs"
  RustCrate* = "api"

import std/json

type
  CreateRoomPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc createRoomResponse*(roomId: string): JsonNode =
  %*{"room_id": roomId}

proc creationContent*(creatorUserId: string; body: JsonNode): JsonNode =
  result = newJObject()
  result["creator"] = %creatorUserId
  if not body.isNil and body.kind == JObject and body.hasKey("creation_content") and
      body["creation_content"].kind == JObject:
    for key, val in body["creation_content"]:
      result[key] = val

proc roomCreatePolicy*(canCreateRoom = true): CreateRoomPolicyResult =
  if not canCreateRoom:
    return (false, "M_FORBIDDEN", "Room creation has been disabled.")
  (true, "", "")

proc inviteList*(body: JsonNode): seq[string] =
  result = @[]
  if body.isNil or body.kind != JObject or not body.hasKey("invite") or body["invite"].kind != JArray:
    return
  for invitee in body["invite"]:
    let userId = invitee.getStr("")
    if userId.len > 0:
      result.add(userId)

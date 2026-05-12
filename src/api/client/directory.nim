const
  RustPath* = "api/client/directory.rs"
  RustCrate* = "api"

import std/[json, strutils]

type
  DirectoryPolicyResult* = tuple[ok: bool, errcode: string, message: string]

  PublicRoomsRequest* = object
    searchTerm*: string
    startIndex*: int
    limit*: int

proc parsePublicRoomsRequest*(body: JsonNode): PublicRoomsRequest =
  result = PublicRoomsRequest(searchTerm: "", startIndex: 0, limit: high(int))
  if body.isNil or body.kind != JObject:
    return
  if body.hasKey("filter") and body["filter"].kind == JObject:
    result.searchTerm = body["filter"]{"generic_search_term"}.getStr("").toLowerAscii()
  if body.hasKey("limit"):
    result.limit = max(0, body["limit"].getInt(result.limit))
  if body.hasKey("since"):
    let raw = body["since"].getStr("0")
    try:
      if raw.len > 1 and raw[0] in {'n', 'p'}:
        let parsed = max(0, parseInt(raw[1 .. ^1]))
        result.startIndex =
          if raw[0] == 'p':
            max(0, parsed - max(1, min(result.limit, 100)))
          else:
            parsed
      else:
        result.startIndex = max(0, parseInt(raw))
    except ValueError:
      result.startIndex = 0

proc publicRoomChunk*(
  roomId, name: string;
  numJoinedMembers: int;
  canonicalAlias = "";
  worldReadable = false;
  guestCanJoin = false;
  roomType = "";
  topic = "";
  avatarUrl = "";
): JsonNode =
  result = %*{
    "room_id": roomId,
    "name": name,
    "num_joined_members": numJoinedMembers,
    "world_readable": worldReadable,
    "guest_can_join": guestCanJoin,
  }
  if canonicalAlias.len > 0:
    result["canonical_alias"] = %canonicalAlias
  if roomType.len > 0:
    result["room_type"] = %roomType
  if topic.len > 0:
    result["topic"] = %topic
  if avatarUrl.len > 0:
    result["avatar_url"] = %avatarUrl

proc publicRoomsResponse*(
  chunk: JsonNode;
  totalRoomCountEstimate: int;
  nextBatch = "";
  prevBatch = "";
): JsonNode =
  result = %*{
    "chunk": if chunk.isNil: newJArray() else: chunk.copy(),
    "total_room_count_estimate": totalRoomCountEstimate,
  }
  if prevBatch.len > 0:
    result["prev_batch"] = %prevBatch
  if nextBatch.len > 0:
    result["next_batch"] = %nextBatch

proc visibilityPayload*(visibility: string): JsonNode =
  %*{"visibility": visibility}

proc visibilityWriteResponse*(): JsonNode =
  newJObject()

proc visibilityToJoinRule*(visibility: string): tuple[ok: bool, joinRule: string, errcode: string, message: string] =
  case visibility
  of "public":
    (true, "public", "", "")
  of "private", "":
    (true, "invite", "", "")
  else:
    (false, "", "M_INVALID_PARAM", "Room visibility type is not supported.")

proc roomVisibilityPolicy*(roomExists: bool): DirectoryPolicyResult =
  if not roomExists:
    return (false, "M_NOT_FOUND", "Room not found.")
  (true, "", "")

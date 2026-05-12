const
  RustPath* = "api/client/sync/v5.rs"
  RustCrate* = "api"

import std/[json, strutils]

import api/client/sync/v5/[extensions, rooms, selector]

export extensions, rooms, selector

proc parseSlidingSyncPos*(pos: string): uint64 =
  if pos.len == 0:
    return 0'u64
  try:
    parseUInt(pos)
  except ValueError:
    var digits = ""
    for ch in pos:
      if ch.isDigit:
        digits.add(ch)
    if digits.len == 0:
      0'u64
    else:
      parseUInt(digits)

proc listResponseJson*(lists: OrderedTable[string, ResponseList]; roomsByList: OrderedTable[string, seq[string]]): JsonNode =
  result = newJObject()
  for listId, list in lists:
    let roomIds = roomsByList.getOrDefault(listId, @[])
    result[listId] = responseListJson(list, roomIds)

proc syncV5Response*(
  pos: uint64;
  lists: JsonNode;
  rooms: JsonNode;
  extensions: JsonNode;
  txnId = ""
): JsonNode =
  result = %*{
    "pos": $pos,
    "lists": if lists.isNil: newJObject() else: lists.copy(),
    "rooms": if rooms.isNil: newJObject() else: rooms.copy(),
    "extensions": if extensions.isNil: newJObject() else: extensions.copy(),
  }
  if txnId.len > 0:
    result["txn_id"] = %txnId

proc isEmptyResponse*(response: JsonNode): bool =
  if response.isNil or response.kind != JObject:
    return true
  response{"rooms"}.len == 0 and response{"extensions"}.len == 0

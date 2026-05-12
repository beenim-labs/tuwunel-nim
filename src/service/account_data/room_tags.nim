const
  RustPath* = "service/account_data/room_tags.rs"
  RustCrate* = "service"

import std/json
import "service/account_data/mod" as account_data_service

type
  AccountDataStore* = account_data_service.AccountDataStore
  AccountDataResult* = account_data_service.AccountDataResult

proc getRoomTags*(store: AccountDataStore; userId, roomId: string): JsonNode =
  let tags = account_data_service.getRoom(store, roomId, userId, "m.tag", tombstoneIsMissing = true)
  if not tags.ok or tags.event.kind != JObject:
    return newJObject()
  if tags.event{"tags"}.isNil or tags.event{"tags"}.kind != JObject:
    return newJObject()
  tags.event{"tags"}.copy()

proc setRoomTag*(
  store: var AccountDataStore;
  userId, roomId, tag: string;
  info: JsonNode = nil;
): AccountDataResult =
  var tags = getRoomTags(store, userId, roomId)
  tags[tag] = if info.isNil: newJObject() else: info.copy()
  account_data_service.update(
    store,
    roomId,
    userId,
    "m.tag",
    %*{
      "type": "m.tag",
      "content": {"tags": tags},
    },
  )

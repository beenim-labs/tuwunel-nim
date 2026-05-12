const
  RustPath* = "service/account_data/direct.rs"
  RustCrate* = "service"

import std/json
import "service/account_data/mod" as account_data_service

type
  AccountDataStore* = account_data_service.AccountDataStore

proc isDirect*(store: AccountDataStore; userId, roomId: string): bool =
  let direct = account_data_service.getGlobal(store, userId, "m.direct", tombstoneIsMissing = true)
  if not direct.ok or direct.event.kind != JObject:
    return false
  for _, rooms in direct.event:
    if rooms.kind != JArray:
      continue
    for candidate in rooms:
      if candidate.getStr("") == roomId:
        return true
  false

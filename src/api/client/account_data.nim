## client/account_data — api module.
##
## Ported from Rust api/client/account_data.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/account_data.rs"
  RustCrate* = "api"

proc setGlobalAccountDataRoute*() =
  ## Ported from `set_global_account_data_route`.
  discard

proc setRoomAccountDataRoute*() =
  ## Ported from `set_room_account_data_route`.
  discard

proc getGlobalAccountDataRoute*() =
  ## Ported from `get_global_account_data_route`.
  discard

proc getRoomAccountDataRoute*() =
  ## Ported from `get_room_account_data_route`.
  discard

proc setAccountData*(services: Services; roomId: Option[string]; senderUser: string; eventTypeS: string; data: RawJsonValue) =
  ## Ported from `set_account_data`.
  discard

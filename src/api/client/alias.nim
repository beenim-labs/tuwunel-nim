## client/alias — api module.
##
## Ported from Rust api/client/alias.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/alias.rs"
  RustCrate* = "api"

proc createAliasRoute*() =
  ## Ported from `create_alias_route`.
  discard

proc deleteAliasRoute*() =
  ## Ported from `delete_alias_route`.
  discard

proc getAliasRoute*() =
  ## Ported from `get_alias_route`.
  discard

proc roomAvailableServers*(services: Services; roomId: string; roomAlias: RoomAliasId; preServers: seq[string]): seq[string] =
  ## Ported from `room_available_servers`.
  @[]

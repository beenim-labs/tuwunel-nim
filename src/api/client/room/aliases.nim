const
  RustPath* = "api/client/room/aliases.rs"
  RustCrate* = "api"

import std/json

type
  RoomAliasesPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc aliasesPayload*(aliases: openArray[string]): JsonNode =
  var arr = newJArray()
  for alias in aliases:
    if alias.len > 0:
      arr.add(%alias)
  %*{"aliases": arr}

proc aliasesAccessPolicy*(canSeeStateEvents: bool): RoomAliasesPolicyResult =
  if not canSeeStateEvents:
    return (false, "M_FORBIDDEN", "You don't have permission to view this room.")
  (true, "", "")

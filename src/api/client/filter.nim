const
  RustPath* = "api/client/filter.rs"
  RustCrate* = "api"

import std/json

type
  FilterPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc filterAccessPolicy*(
  senderUser, targetUser: string;
  isAppservice = false;
): FilterPolicyResult =
  if senderUser != targetUser and not isAppservice:
    return (false, "M_FORBIDDEN", "You cannot access filters for other users.")
  (true, "", "")

proc filterKey*(userId, filterId: string): string =
  userId & "\x1f" & filterId

proc createFilterResponse*(filterId: string): JsonNode =
  %*{"filter_id": filterId}

proc filterPayload*(filter: JsonNode): JsonNode =
  if filter.isNil: newJObject() else: filter.copy()

proc filterNotFound*(): FilterPolicyResult =
  (false, "M_NOT_FOUND", "Filter not found.")

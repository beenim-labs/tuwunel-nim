const
  RustPath* = "api/client/user_directory.rs"
  RustCrate* = "api"
  LimitDefault* = 10
  LimitMax* = 500

import std/[json, strutils]

proc userDirectoryLimit*(body: JsonNode): int =
  if body.isNil or body.kind != JObject:
    return LimitDefault
  max(1, min(LimitMax, body{"limit"}.getInt(LimitDefault)))

proc userMatchesSearch*(userId, username, displayName, searchTerm: string): bool =
  if searchTerm.len == 0:
    return true
  let haystack = (userId & " " & username & " " & displayName).toLowerAscii()
  searchTerm.toLowerAscii() in haystack

proc userDirectoryItem*(userId: string; displayName = ""; avatarUrl = ""): JsonNode =
  result = %*{"user_id": userId}
  if displayName.len > 0:
    result["display_name"] = %displayName
  if avatarUrl.len > 0:
    result["avatar_url"] = %avatarUrl

proc userDirectoryResponse*(items: openArray[JsonNode]; limited: bool): JsonNode =
  var results = newJArray()
  for item in items:
    results.add(if item.isNil: newJObject() else: item.copy())
  %*{
    "limited": limited,
    "results": results,
  }

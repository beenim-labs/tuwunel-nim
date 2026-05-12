const
  RustPath* = "api/client/alias.rs"
  RustCrate* = "api"

import std/[json, sets]

type
  AliasPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc aliasResponse*(roomId: string; servers: openArray[string]): JsonNode =
  var serverArray = newJArray()
  for server in servers:
    if server.len > 0:
      serverArray.add(%server)
  %*{
    "room_id": roomId,
    "servers": serverArray,
  }

proc aliasWriteResponse*(): JsonNode =
  newJObject()

proc aliasNotFound*(): AliasPolicyResult =
  (false, "M_NOT_FOUND", "Room with alias not found.")

proc aliasConflict*(): AliasPolicyResult =
  (false, "M_CONFLICT", "Alias already exists.")

proc aliasesFromCanonicalContent*(content: JsonNode): seq[string] =
  result = @[]
  if content.isNil or content.kind != JObject:
    return
  var seen = initHashSet[string]()
  let canonical = content{"alias"}.getStr("")
  if canonical.len > 0:
    result.add(canonical)
    seen.incl(canonical)
  if content.hasKey("alt_aliases") and content["alt_aliases"].kind == JArray:
    for aliasNode in content["alt_aliases"]:
      let alias = aliasNode.getStr("")
      if alias.len > 0 and alias notin seen:
        result.add(alias)
        seen.incl(alias)

proc aliasContentWith*(content: JsonNode; alias: string): JsonNode =
  if not content.isNil and content.kind == JObject:
    result = content.copy()
  else:
    result = newJObject()

  let existingAlias = result{"alias"}.getStr("")
  if existingAlias.len == 0:
    result["alias"] = %alias
    return
  if existingAlias == alias:
    return

  var alt = newJArray()
  var seen = initHashSet[string]()
  if result.hasKey("alt_aliases") and result["alt_aliases"].kind == JArray:
    for node in result["alt_aliases"]:
      let item = node.getStr("")
      if item.len > 0 and item != existingAlias and item notin seen:
        alt.add(%item)
        seen.incl(item)
  if alias.len > 0 and alias notin seen:
    alt.add(%alias)
  result["alt_aliases"] = alt

proc aliasContentWithout*(content: JsonNode; alias: string): JsonNode =
  if content.isNil or content.kind != JObject:
    return newJObject()
  result = content.copy()

  var altValues: seq[string] = @[]
  if result.hasKey("alt_aliases") and result["alt_aliases"].kind == JArray:
    for node in result["alt_aliases"]:
      let item = node.getStr("")
      if item.len > 0 and item != alias:
        altValues.add(item)

  if result{"alias"}.getStr("") == alias:
    if altValues.len > 0:
      result["alias"] = %altValues[0]
      altValues.delete(0)
    elif result.hasKey("alias"):
      result.delete("alias")

  var alt = newJArray()
  for item in altValues:
    if item != result{"alias"}.getStr(""):
      alt.add(%item)
  if alt.len > 0:
    result["alt_aliases"] = alt
  elif result.hasKey("alt_aliases"):
    result.delete("alt_aliases")

import std/json

proc jsonField*(node: JsonNode; key: string): JsonNode =
  if node.isNil or node.kind != JObject or not node.hasKey(key):
    return newJNull()
  node[key]

proc jsonObjectField*(node: JsonNode; key: string): JsonNode =
  let value = jsonField(node, key)
  if value.kind == JObject:
    value
  else:
    newJObject()

proc jsonContent*(event: JsonNode): JsonNode =
  jsonObjectField(event, "content")

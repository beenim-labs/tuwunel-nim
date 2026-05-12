import std/json

const
  RustPath* = "api/server/query.rs"
  RustCrate* = "api"

proc directoryPayload*(
    roomId: string;
    servers: openArray[string]
): tuple[ok: bool, payload: JsonNode] =
  if roomId.len == 0:
    return (false, newJObject())
  var serverList = newJArray()
  for server in servers:
    if server.len > 0:
      serverList.add(%server)
  (true, %*{"room_id": roomId, "servers": serverList})

proc profilePayload*(
    fullProfile: JsonNode;
    field = ""
): tuple[ok: bool, payload: JsonNode] =
  if fullProfile.kind != JObject:
    return (false, newJObject())
  if field.len == 0:
    return (true, fullProfile.copy())
  if not fullProfile.hasKey(field):
    return (false, newJObject())
  (true, %*{field: fullProfile[field]})

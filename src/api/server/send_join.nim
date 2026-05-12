const
  RustPath* = "api/server/send_join.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/[json, strutils]

proc sendJoinPayload*(
    stateEvents, authChain: JsonNode;
    event: JsonNode;
    membersOmitted: bool;
    origin: string;
    serversInRoom: JsonNode = nil
): tuple[ok: bool, payload: JsonNode] =
  if stateEvents.isNil or stateEvents.kind != JArray:
    return (false, newJObject())
  if authChain.isNil or authChain.kind != JArray:
    return (false, newJObject())
  if event.isNil or event.kind != JObject:
    return (false, newJObject())
  if origin.strip().len == 0:
    return (false, newJObject())

  result = (true, %*{
    "state": stateEvents,
    "auth_chain": authChain,
    "event": event,
    "members_omitted": membersOmitted,
    "origin": origin
  })
  if not serversInRoom.isNil and serversInRoom.kind == JArray:
    result.payload["servers_in_room"] = serversInRoom

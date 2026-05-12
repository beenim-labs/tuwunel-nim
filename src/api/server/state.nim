const
  RustPath* = "api/server/state.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/json

proc roomStatePayload*(
    authChain, pdus: JsonNode
): tuple[ok: bool, payload: JsonNode] =
  if authChain.isNil or authChain.kind != JArray:
    return (false, newJObject())
  if pdus.isNil or pdus.kind != JArray:
    return (false, newJObject())

  (true, %*{
    "auth_chain": authChain,
    "pdus": pdus
  })

proc roomStatePayload*(authChain, pdus: openArray[JsonNode]): tuple[ok: bool, payload: JsonNode] =
  var authArray = newJArray()
  for event in authChain:
    authArray.add(event)

  var pduArray = newJArray()
  for event in pdus:
    pduArray.add(event)

  roomStatePayload(authArray, pduArray)

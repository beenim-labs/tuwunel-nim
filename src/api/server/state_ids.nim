const
  RustPath* = "api/server/state_ids.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/json

proc idsArray*(eventIds: openArray[string]): JsonNode =
  result = newJArray()
  for eventId in eventIds:
    if eventId.len > 0:
      result.add(%eventId)

proc roomStateIdsPayload*(
    authChainIds, pduIds: JsonNode
): tuple[ok: bool, payload: JsonNode] =
  if authChainIds.isNil or authChainIds.kind != JArray:
    return (false, newJObject())
  if pduIds.isNil or pduIds.kind != JArray:
    return (false, newJObject())

  (true, %*{
    "auth_chain_ids": authChainIds,
    "pdu_ids": pduIds
  })

proc roomStateIdsPayload*(
    authChainIds, pduIds: openArray[string]
): tuple[ok: bool, payload: JsonNode] =
  roomStateIdsPayload(idsArray(authChainIds), idsArray(pduIds))

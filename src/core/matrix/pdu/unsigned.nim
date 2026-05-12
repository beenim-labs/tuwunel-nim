const
  RustPath* = "core/matrix/pdu/unsigned.rs"
  RustCrate* = "core"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/[json, times]

proc ensureUnsignedObject(event: var JsonNode) =
  if event.kind != JObject:
    event = newJObject()
  if event{"unsigned"}.kind != JObject:
    event["unsigned"] = newJObject()

proc removeTransactionId*(event: var JsonNode) =
  ensureUnsignedObject(event)
  event["unsigned"].delete("transaction_id")

proc addAge*(event: var JsonNode; nowMs = -1'i64) =
  ensureUnsignedObject(event)
  let effectiveNow =
    if nowMs >= 0:
      nowMs
    else:
      (epochTime() * 1000).int64
  let then = event{"origin_server_ts"}.getInt(0).int64
  event["unsigned"]["age"] = %(effectiveNow - then)

proc addRelation*(event: var JsonNode; name: string; relatedPdu: JsonNode = nil) =
  ensureUnsignedObject(event)
  if event["unsigned"]{"m.relations"}.kind != JObject:
    event["unsigned"]["m.relations"] = newJObject()
  event["unsigned"]["m.relations"][name] =
    if relatedPdu.isNil:
      newJObject()
    else:
      relatedPdu.copy()

const
  RustPath* = "api/client/redact.rs"
  RustCrate* = "api"

import std/json

type
  RedactPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc redactResponse*(eventId: string): JsonNode =
  %*{"event_id": eventId}

proc redactionContent*(body: JsonNode; redactsEventId: string): JsonNode =
  result =
    if body.isNil or body.kind != JObject:
      newJObject()
    else:
      body.copy()
  result["redacts"] = %redactsEventId

proc redactAccessPolicy*(roomExists, canRedact: bool; redactionsAllowed = true): RedactPolicyResult =
  if not roomExists:
    return (false, "M_NOT_FOUND", "Room not found.")
  if not canRedact:
    return (false, "M_FORBIDDEN", "You are not joined to this room.")
  if not redactionsAllowed:
    return (false, "M_FORBIDDEN", "Redactions are disabled on this server.")
  (true, "", "")

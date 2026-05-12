const
  RustPath* = "api/client/room/summary.rs"
  RustCrate* = "api"

import std/json

type
  SummaryPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc summaryPolicy*(roomExists, canViewSummary: bool): SummaryPolicyResult =
  if not roomExists:
    return (false, "M_NOT_FOUND", "Room not found.")
  if not canViewSummary:
    return (false, "M_FORBIDDEN", "Room is not world readable or publicly accessible.")
  (true, "", "")

proc summaryResponse*(summary: JsonNode; membership = ""): JsonNode =
  result =
    if summary.isNil:
      newJObject()
    else:
      summary.copy()
  if membership.len > 0:
    result["membership"] = %membership

const
  RustPath* = "api/client/report.rs"
  RustCrate* = "api"
  ReasonMaxLen* = 750

import std/json

type
  ReportPolicyResult* = tuple[ok: bool, errcode: string, message: string]

  ReportBody* = object
    reason*: string
    score*: int

proc parseReportBody*(body: JsonNode): tuple[ok: bool, report: ReportBody, errcode: string, message: string] =
  if body.isNil or body.kind != JObject:
    return (false, ReportBody(), "M_BAD_JSON", "Invalid JSON body.")
  var reason = ""
  if body.hasKey("reason") and body["reason"].kind != JNull:
    if body["reason"].kind != JString:
      return (false, ReportBody(), "M_BAD_JSON", "reason must be a string.")
    reason = body["reason"].getStr("")
  if reason.len > ReasonMaxLen:
    return (
      false,
      ReportBody(),
      "M_INVALID_PARAM",
      "Reason too long, should be 750 characters or fewer.",
    )
  let score =
    if body.hasKey("score") and body["score"].kind == JInt:
      body["score"].getInt(0)
    else:
      0
  (true, ReportBody(reason: reason, score: score), "", "")

proc reportTargetPolicy*(
  foundRoom: bool;
  eventExists = true;
  reporterInRoom = true;
  stored = true;
): ReportPolicyResult =
  if not foundRoom:
    return (false, "M_NOT_FOUND", "Room not found.")
  if not eventExists:
    return (false, "M_NOT_FOUND", "Event ID is not known to us or Event ID is invalid.")
  if not reporterInRoom:
    return (false, "M_NOT_FOUND", "You are not in the room you are reporting.")
  if not stored:
    return (false, "M_NOT_FOUND", "Report target not found.")
  (true, "", "")

proc reportResponse*(): JsonNode =
  newJObject()

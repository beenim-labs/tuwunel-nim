const
  RustPath* = "api/client/context.rs"
  RustCrate* = "api"
  LimitDefault* = 10
  LimitMax* = 100

import std/json

type
  ContextPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc contextLimit*(raw: int): int =
  if raw < 0:
    0
  elif raw == 0:
    LimitDefault
  else:
    min(raw, LimitMax)

proc contextAccessPolicy*(roomExists, canViewRoom, eventExists: bool): ContextPolicyResult =
  if not roomExists:
    return (false, "M_NOT_FOUND", "Room not found.")
  if not canViewRoom:
    return (false, "M_FORBIDDEN", "You don't have permission to view this event.")
  if not eventExists:
    return (false, "M_NOT_FOUND", "Event not found.")
  (true, "", "")

proc contextResponse*(
  event: JsonNode;
  eventsBefore, eventsAfter, state: JsonNode;
  start = "";
  ending = "";
): JsonNode =
  %*{
    "event": if event.isNil: newJNull() else: event.copy(),
    "events_before": if eventsBefore.isNil: newJArray() else: eventsBefore.copy(),
    "events_after": if eventsAfter.isNil: newJArray() else: eventsAfter.copy(),
    "start": start,
    "end": ending,
    "state": if state.isNil: newJArray() else: state.copy(),
  }

proc eventContextResponse*(
  eventsBefore, eventsAfter: JsonNode;
  start = "";
  ending = "";
): JsonNode =
  %*{
    "profile_info": {},
    "events_before": if eventsBefore.isNil: newJArray() else: eventsBefore.copy(),
    "events_after": if eventsAfter.isNil: newJArray() else: eventsAfter.copy(),
    "start": start,
    "end": ending,
  }

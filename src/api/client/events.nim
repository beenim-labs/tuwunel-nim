const
  RustPath* = "api/client/events.rs"
  RustCrate* = "api"
  EventLimit* = 50

import std/json

type
  EventsPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc eventsAccessPolicy*(canSeeStateEvents: bool): EventsPolicyResult =
  if not canSeeStateEvents:
    return (false, "M_FORBIDDEN", "No room preview available.")
  (true, "", "")

proc normalizeEventsLimit*(limit: int): int =
  max(1, min(EventLimit, limit))

proc normalizeEventsTimeout*(requestedMs, defaultMs, minMs, maxMs: int64): int64 =
  let base =
    if requestedMs >= 0:
      requestedMs
    else:
      defaultMs
  max(minMs, min(maxMs, base))

proc eventsResponse*(chunk: openArray[JsonNode]; start = ""; ending = ""): JsonNode =
  var events = newJArray()
  for event in chunk:
    events.add(if event.isNil: newJObject() else: event.copy())
  result = %*{
    "chunk": events,
    "start": start,
    "end": ending,
  }

proc eventsResponse*(chunk: JsonNode; start = ""; ending = ""): JsonNode =
  var events = newJArray()
  if chunk.isNil:
    discard
  elif chunk.kind == JArray:
    events = chunk.copy()
  else:
    events.add(chunk.copy())
  %*{
    "chunk": events,
    "start": start,
    "end": ending,
  }

proc emptyEventsResponse*(start = ""; ending = ""): JsonNode =
  let empty: seq[JsonNode] = @[]
  eventsResponse(empty, start, ending)

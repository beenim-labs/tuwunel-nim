const
  RustPath* = "api/server/get_missing_events.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/[json, sets, tables]

const
  LimitDefault* = 10
  LimitMax* = 50

type
  MissingEvent* = object
    eventId*: string
    streamPos*: int64
    prevEventIds*: seq[string]
    pdu*: JsonNode

proc missingEvent*(
    eventId: string;
    streamPos: int64;
    pdu: JsonNode;
    prevEventIds: openArray[string] = []
): MissingEvent =
  result = MissingEvent(eventId: eventId, streamPos: streamPos, pdu: pdu)
  for eventId in prevEventIds:
    if eventId.len > 0:
      result.prevEventIds.add(eventId)

proc eventIdsFromJsonArray*(body: JsonNode; field: string): seq[string] =
  result = @[]
  if body.isNil or body.kind != JObject:
    return
  if not body.hasKey(field) or body[field].kind != JArray:
    return
  for node in body[field]:
    let eventId = node.getStr("")
    if eventId.len > 0:
      result.add(eventId)

proc normalizeLimit*(limit: int): int =
  max(0, min(LimitMax, limit))

proc limitFromBody*(body: JsonNode): int =
  if body.isNil or body.kind != JObject:
    return LimitDefault
  normalizeLimit(body{"limit"}.getInt(LimitDefault))

proc missingEventsPayload*(events: JsonNode): tuple[ok: bool, payload: JsonNode] =
  if events.isNil or events.kind != JArray:
    return (false, newJObject())
  (true, %*{"events": events})

proc selectMissingEvents*(
    timeline: openArray[MissingEvent];
    earliestEventIds, latestEventIds: openArray[string];
    limit: int
): seq[MissingEvent] =
  result = @[]
  let cappedLimit = normalizeLimit(limit)
  if cappedLimit == 0:
    return

  var byId = initTable[string, MissingEvent]()
  for ev in timeline:
    if ev.eventId.len > 0:
      byId[ev.eventId] = ev

  var earliest = initHashSet[string]()
  for eventId in earliestEventIds:
    if eventId.len > 0:
      earliest.incl(eventId)

  var queued: seq[string] = @[]
  var seen = initHashSet[string]()
  for eventId in latestEventIds:
    if eventId.len > 0 and eventId notin seen:
      queued.add(eventId)
      seen.incl(eventId)

  var cursor = 0
  while cursor < queued.len and result.len < cappedLimit:
    let eventId = queued[cursor]
    inc cursor
    if eventId notin byId or eventId in earliest:
      continue
    let ev = byId[eventId]
    result.add(ev)
    for prevId in ev.prevEventIds:
      if prevId.len > 0 and prevId notin seen:
        queued.add(prevId)
        seen.incl(prevId)

proc selectMissingEventsByPosition*(
    timeline: openArray[MissingEvent];
    earliestEventIds, latestEventIds: openArray[string];
    limit: int
): seq[MissingEvent] =
  result = @[]
  let cappedLimit = normalizeLimit(limit)
  if cappedLimit == 0:
    return

  var earliestPos = 0'i64
  for eventId in earliestEventIds:
    for ev in timeline:
      if ev.eventId == eventId:
        earliestPos = max(earliestPos, ev.streamPos)
        break

  var latestPos = high(int64)
  for eventId in latestEventIds:
    for ev in timeline:
      if ev.eventId == eventId:
        latestPos = min(latestPos, ev.streamPos)
        break

  for ev in timeline:
    if ev.streamPos <= earliestPos or ev.streamPos >= latestPos:
      continue
    result.add(ev)
    if result.len >= cappedLimit:
      break

proc missingEventsPayload*(
    timeline: openArray[MissingEvent];
    earliestEventIds, latestEventIds: openArray[string];
    limit: int
): tuple[ok: bool, payload: JsonNode] =
  var events = newJArray()
  for ev in selectMissingEvents(timeline, earliestEventIds, latestEventIds, limit):
    events.add(ev.pdu)
  missingEventsPayload(events)

proc missingEventsPayloadByPosition*(
    timeline: openArray[MissingEvent];
    body: JsonNode
): tuple[ok: bool, payload: JsonNode] =
  var events = newJArray()
  for ev in selectMissingEventsByPosition(
    timeline,
    eventIdsFromJsonArray(body, "earliest_events"),
    eventIdsFromJsonArray(body, "latest_events"),
    limitFromBody(body),
  ):
    events.add(ev.pdu)
  missingEventsPayload(events)

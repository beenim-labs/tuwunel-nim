const
  RustPath* = "api/server/backfill.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/[json, strutils]

const
  LimitDefault* = 50
  LimitMax* = 150

type
  BackfillEvent* = object
    eventId*: string
    streamPos*: int64
    pdu*: JsonNode

proc backfillEvent*(eventId: string; streamPos: int64; pdu: JsonNode): BackfillEvent =
  BackfillEvent(eventId: eventId, streamPos: streamPos, pdu: pdu)

proc normalizeLimit*(limit: int): int =
  max(0, min(LimitMax, limit))

proc selectBackfillEvents*(
    timeline: openArray[BackfillEvent];
    fromEventIds: openArray[string];
    limit: int
): seq[BackfillEvent] =
  let cappedLimit = normalizeLimit(limit)
  if cappedLimit == 0:
    return @[]

  var fromPos = low(int64)
  for eventId in fromEventIds:
    for ev in timeline:
      if ev.eventId == eventId:
        fromPos = max(fromPos, ev.streamPos)
        break

  if fromPos == low(int64):
    if timeline.len == 0:
      fromPos = 0
    else:
      fromPos = timeline[^1].streamPos + 1

  result = @[]
  for idx in countdown(timeline.high, 0):
    let ev = timeline[idx]
    if ev.streamPos >= fromPos:
      continue
    result.add(ev)
    if result.len >= cappedLimit:
      break

proc backfillPayload*(
    origin: string;
    originServerTs: int64;
    pdus: JsonNode
): tuple[ok: bool, payload: JsonNode] =
  if origin.strip().len == 0 or pdus.isNil or pdus.kind != JArray:
    return (false, newJObject())

  (true, %*{
    "origin": origin,
    "origin_server_ts": originServerTs,
    "pdus": pdus
  })

proc backfillPayload*(
    origin: string;
    originServerTs: int64;
    timeline: openArray[BackfillEvent];
    fromEventIds: openArray[string];
    limit: int
): tuple[ok: bool, payload: JsonNode] =
  var pdus = newJArray()
  for ev in selectBackfillEvents(timeline, fromEventIds, limit):
    pdus.add(ev.pdu)

  backfillPayload(origin, originServerTs, pdus)

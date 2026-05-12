const
  RustPath* = "api/client/search.rs"
  RustCrate* = "api"
  LimitDefault* = 10
  LimitMax* = 100

import std/[json, sets, strutils]

proc searchLimit*(filter: JsonNode): int =
  if filter.isNil or filter.kind != JObject or not filter.hasKey("limit"):
    return LimitDefault
  max(1, min(LimitMax, filter["limit"].getInt(LimitDefault)))

proc searchHighlights*(searchTerm: string): JsonNode =
  result = newJArray()
  var seen = initHashSet[string]()
  for raw in searchTerm.split(AllChars - Letters - Digits):
    let term = raw.strip().toLowerAscii()
    if term.len == 0 or term in seen:
      continue
    seen.incl(term)
    result.add(%term)

proc emptyRoomEventsResponse*(): JsonNode =
  %*{"search_categories": {"room_events": {
    "count": 0,
    "highlights": [],
    "results": [],
    "state": {}
  }}}

proc searchResult*(event, context: JsonNode; rank = 1.0): JsonNode =
  %*{
    "rank": rank,
    "result": if event.isNil: newJObject() else: event.copy(),
    "context": if context.isNil: newJObject() else: context.copy(),
  }

proc roomEventsResponse*(
  count: int;
  highlights, results, state: JsonNode;
  nextBatch = "";
): JsonNode =
  var roomEvents = %*{
    "count": count,
    "highlights": if highlights.isNil: newJArray() else: highlights.copy(),
    "results": if results.isNil: newJArray() else: results.copy(),
    "state": if state.isNil: newJObject() else: state.copy(),
  }
  if nextBatch.len > 0:
    roomEvents["next_batch"] = %nextBatch
  %*{"search_categories": {"room_events": roomEvents}}

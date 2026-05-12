const
  RustPath* = "core/matrix/state_res/resolve/mainline_sort.rs"
  RustCrate* = "core"

import std/[algorithm, json, options, tables]

import core/matrix/state_res/event_format
import core/matrix/state_res/resolve/types

type
  MainlineSortResult* = tuple[ok: bool, eventIds: seq[EventId], message: string]

proc powerLevelsAuthEventId(event: JsonNode; eventsById: Table[EventId, JsonNode]): Option[EventId] =
  for authEventId in event.authEvents():
    if eventsById.hasKey(authEventId) and
        eventsById[authEventId].isTypeAndStateKey("m.room.power_levels", ""):
      return some(authEventId)
  none(EventId)

proc mainlineFromPowerEvent(
  powerLevelEventId: Option[EventId];
  eventsById: Table[EventId, JsonNode]
): seq[EventId] =
  result = @[]
  var current = powerLevelEventId
  while current.isSome:
    let eventId = current.get()
    if eventId in result or not eventsById.hasKey(eventId):
      break
    result.add(eventId)
    current = powerLevelsAuthEventId(eventsById[eventId], eventsById)
  result.reverse()

proc mainlinePosition(
  event: JsonNode;
  mainline: openArray[EventId];
  eventsById: Table[EventId, JsonNode]
): int =
  var current = event
  var seen: seq[EventId] = @[]
  while not current.isNil and current.kind == JObject:
    let currentId = current.eventId()
    for index, mainlineId in mainline:
      if currentId == mainlineId:
        return index + 1
    if currentId.len == 0 or currentId in seen:
      break
    seen.add(currentId)
    let nextId = powerLevelsAuthEventId(current, eventsById)
    if nextId.isNone or not eventsById.hasKey(nextId.get()):
      break
    current = eventsById[nextId.get()]
  0

proc mainlineSort*(
  powerLevelEventId: Option[EventId];
  eventIds: openArray[EventId];
  eventsById: Table[EventId, JsonNode]
): MainlineSortResult =
  result = (true, @[], "")
  let mainline = mainlineFromPowerEvent(powerLevelEventId, eventsById)
  var sortable: seq[tuple[eventId: EventId, position: int, originServerTs: int64]] = @[]
  for eventId in eventIds:
    if not eventsById.hasKey(eventId):
      return (false, @[], "event not found: " & eventId)
    let event = eventsById[eventId]
    sortable.add((eventId, event.mainlinePosition(mainline, eventsById), event.originServerTs()))

  sortable.sort(proc(a, b: tuple[eventId: EventId, position: int, originServerTs: int64]): int =
    result = system.cmp(a.position, b.position)
    if result == 0:
      result = system.cmp(a.originServerTs, b.originServerTs)
    if result == 0:
      result = system.cmp(a.eventId, b.eventId)
  )
  for item in sortable:
    result.eventIds.add(item.eventId)

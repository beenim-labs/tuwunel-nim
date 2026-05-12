const
  RustPath* = "core/matrix/state_res/resolve/power_sort.rs"
  RustCrate* = "core"

import std/[json, options, tables]

import core/matrix/state_res/event_format
import core/matrix/state_res/events
import core/matrix/state_res/events/[create, power_levels]
import core/matrix/state_res/resolve/[topological_sort, types]
import core/matrix/state_res/rules

type
  PowerSortResult* = tuple[ok: bool, eventIds: seq[EventId], message: string]

proc addEventAuthChain(
  fullConflictedSet: openArray[EventId];
  graph: var EventGraph;
  eventId: EventId;
  eventsById: Table[EventId, JsonNode]
) =
  var todo = @[eventId]
  while todo.len > 0:
    let currentId = todo.pop()
    if not eventsById.hasKey(currentId):
      continue
    if not graph.hasKey(currentId):
      graph[currentId] = @[]
    for authEventId in eventsById[currentId].authEvents():
      if authEventId notin fullConflictedSet:
        continue
      if authEventId notin graph[currentId]:
        graph[currentId].add(authEventId)
      if not graph.hasKey(authEventId):
        todo.add(authEventId)

proc firstAuthEvent(
  event: JsonNode;
  eventsById: Table[EventId, JsonNode];
  eventType, stateKey: string
): Option[JsonNode] =
  for authEventId in event.authEvents():
    if eventsById.hasKey(authEventId) and eventsById[authEventId].isTypeAndStateKey(eventType, stateKey):
      return some(eventsById[authEventId])
  none(JsonNode)

proc powerLevelForSender(
  eventId: EventId;
  rules: AuthorizationRules;
  eventsById: Table[EventId, JsonNode]
): tuple[ok: bool, value: int, infinite: bool, message: string] =
  if not eventsById.hasKey(eventId):
    return (false, 0, false, "event not found: " & eventId)
  let event = eventsById[eventId]

  let createEvent = event.firstAuthEvent(eventsById, "m.room.create", "")
  let powerEvent = event.firstAuthEvent(eventsById, "m.room.power_levels", "")

  var creators: seq[string] = @[]
  if createEvent.isSome:
    let parsedCreators = create.roomCreateEvent(createEvent.get()).creators(rules)
    if parsedCreators.ok:
      creators = parsedCreators.values

  let powerLevels =
    if powerEvent.isSome:
      some(power_levels.roomPowerLevelsEvent(powerEvent.get()))
    else:
      none(RoomPowerLevelsEvent)
  powerLevels.userPowerLevel(event.sender(), creators, rules)

proc powerSort*(
  rules: AuthorizationRules;
  fullConflictedSet: openArray[EventId];
  eventsById: Table[EventId, JsonNode]
): PowerSortResult =
  var graph = initOrderedTable[EventId, ReferencedIds]()
  for eventId in sortedEventIds(fullConflictedSet):
    if eventsById.hasKey(eventId) and isPowerEvent(eventsById[eventId]):
      addEventAuthChain(fullConflictedSet, graph, eventId, eventsById)

  var info = initTable[EventId, TieBreakerInfo]()
  for eventId in graph.keys:
    let power = powerLevelForSender(eventId, rules, eventsById)
    if not power.ok:
      return (false, @[], power.message)
    info[eventId] = TieBreakerInfo(
      powerLevel: power.value,
      originServerTs: eventsById[eventId].originServerTs(),
    )

  let sorted = topologicalSort(graph, info)
  if not sorted.ok:
    return (false, sorted.eventIds, sorted.message)
  (true, sorted.eventIds, "")

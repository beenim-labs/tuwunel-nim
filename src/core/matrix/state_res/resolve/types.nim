import std/[algorithm, tables]

import core/matrix/event/state_key

type
  EventId* = string
  StateEntry* = tuple[key: TypeStateKey, eventId: EventId]
  StateMap* = OrderedTable[TypeStateKey, EventId]
  AuthSet* = seq[EventId]
  ConflictEntry* = tuple[key: TypeStateKey, eventIds: seq[EventId]]
  ConflictMap* = OrderedTable[TypeStateKey, seq[EventId]]
  ReferencedIds* = seq[EventId]
  EventGraph* = OrderedTable[EventId, ReferencedIds]

proc stateMap*(entries: openArray[StateEntry]): StateMap =
  result = initOrderedTable[TypeStateKey, EventId]()
  for entry in entries:
    result[entry.key] = entry.eventId

proc eventGraph*(entries: openArray[tuple[eventId: EventId, references: seq[EventId]]]): EventGraph =
  result = initOrderedTable[EventId, ReferencedIds]()
  for entry in entries:
    result[entry.eventId] = entry.references

proc authSet*(ids: openArray[EventId]): AuthSet =
  result = @[]
  for id in ids:
    if id notin result:
      result.add(id)
  result.sort(system.cmp[string])

proc sortedStateKeys*(stateMap: StateMap): seq[TypeStateKey] =
  result = @[]
  for key in stateMap.keys:
    result.add(key)
  result.sort(proc(a, b: TypeStateKey): int = cmp(a, b))

proc sortedStateKeys*(conflicts: ConflictMap): seq[TypeStateKey] =
  result = @[]
  for key in conflicts.keys:
    result.add(key)
  result.sort(proc(a, b: TypeStateKey): int = cmp(a, b))

proc sortedEventIds*(ids: openArray[EventId]): seq[EventId] =
  result = @[]
  for id in ids:
    if id notin result:
      result.add(id)
  result.sort(system.cmp[string])

proc toEntries*(stateMap: StateMap): seq[StateEntry] =
  result = @[]
  for key in stateMap.sortedStateKeys():
    result.add((key, stateMap[key]))

proc toConflictEntries*(conflicts: ConflictMap): seq[ConflictEntry] =
  result = @[]
  for key in conflicts.sortedStateKeys():
    result.add((key, sortedEventIds(conflicts[key])))

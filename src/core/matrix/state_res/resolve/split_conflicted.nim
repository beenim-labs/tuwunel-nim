const
  RustPath* = "core/matrix/state_res/resolve/split_conflicted.rs"
  RustCrate* = "core"

import std/[algorithm, tables]

import core/matrix/event/state_key
import core/matrix/state_res/resolve/types

proc splitConflictedState*(
  stateMaps: openArray[StateMap]
): tuple[unconflicted: StateMap, conflicted: ConflictMap] =
  result = (
    unconflicted: initOrderedTable[TypeStateKey, EventId](),
    conflicted: initOrderedTable[TypeStateKey, seq[EventId]](),
  )
  if stateMaps.len == 0:
    return

  var occurrences = initTable[TypeStateKey, Table[EventId, int]]()
  for stateMap in stateMaps:
    for key, eventId in stateMap:
      if not occurrences.hasKey(key):
        occurrences[key] = initTable[EventId, int]()
      var perId = occurrences[key]
      perId[eventId] = perId.getOrDefault(eventId, 0) + 1
      occurrences[key] = perId

  var keys: seq[TypeStateKey] = @[]
  for key in occurrences.keys:
    keys.add(key)
  keys.sort(proc(a, b: TypeStateKey): int = cmp(a, b))

  for key in keys:
    var unconflictedId = ""
    var conflicts: seq[EventId] = @[]
    for eventId, count in occurrences[key]:
      if count == stateMaps.len:
        unconflictedId = eventId
      else:
        conflicts.add(eventId)
    if unconflictedId.len > 0:
      result.unconflicted[key] = unconflictedId
    if conflicts.len > 0:
      result.conflicted[key] = sortedEventIds(conflicts)

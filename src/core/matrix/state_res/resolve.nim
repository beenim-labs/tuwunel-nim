const
  RustPath* = "core/matrix/state_res/resolve.rs"
  RustCrate* = "core"

import std/[sequtils, sets, tables]

import core/matrix/state_res/resolve/[
  auth_difference,
  conflicted_subgraph,
  iterative_auth_check,
  mainline_sort,
  power_sort,
  split_conflicted,
  topological_sort,
  types,
]

export
  auth_difference,
  conflicted_subgraph,
  iterative_auth_check,
  mainline_sort,
  power_sort,
  split_conflicted,
  topological_sort,
  types

proc fullConflictedSet*(
  conflictedStates: ConflictMap;
  authSets: openArray[AuthSet];
  existingEventIds: HashSet[EventId];
  authGraph = initOrderedTable[EventId, ReferencedIds]();
  considerConflictedSubgraph = false
): seq[EventId] =
  result = @[]
  var full = initHashSet[EventId]()

  for entry in conflictedStates.toConflictEntries():
    for eventId in entry.eventIds:
      if existingEventIds.len == 0 or eventId in existingEventIds:
        full.incl(eventId)

  for eventId in authDifference(authSets):
    if existingEventIds.len == 0 or eventId in existingEventIds:
      full.incl(eventId)

  if considerConflictedSubgraph:
    let conflictedIds = sortedEventIds(toSeq(full))
    for eventId in conflictedSubgraphDfs(conflictedIds, authGraph):
      if existingEventIds.len == 0 or eventId in existingEventIds:
        full.incl(eventId)

  for eventId in full:
    result.add(eventId)
  result = sortedEventIds(result)

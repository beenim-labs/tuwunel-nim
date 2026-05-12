const
  RustPath* = "core/matrix/state_res/resolve/conflicted_subgraph.rs"
  RustCrate* = "core"

import std/[sets, tables]

import core/matrix/state_res/resolve/types

proc addPath(target: var HashSet[EventId]; path: openArray[EventId]) =
  for eventId in path:
    target.incl(eventId)

proc conflictedSubgraphDfs*(
  conflictedSet: openArray[EventId];
  authGraph: EventGraph
): seq[EventId] =
  result = @[]
  var conflicted = initHashSet[EventId]()
  for eventId in conflictedSet:
    conflicted.incl(eventId)

  var subgraph = initHashSet[EventId]()
  let starts = sortedEventIds(conflictedSet)
  for start in starts:
    var stack: seq[tuple[eventId: EventId, path: seq[EventId]]] = @[(start, @[start])]
    var seen = initHashSet[EventId]()
    while stack.len > 0:
      let current = stack.pop()
      if current.eventId in seen:
        continue
      seen.incl(current.eventId)

      if current.path.len > 1 and current.eventId in conflicted:
        subgraph.addPath(current.path)

      if authGraph.hasKey(current.eventId):
        for authEventId in authGraph[current.eventId]:
          var nextPath = current.path
          nextPath.add(authEventId)
          stack.add((authEventId, nextPath))

  for eventId in subgraph:
    result.add(eventId)
  result = sortedEventIds(result)

const
  RustPath* = "core/matrix/state_res/resolve/auth_difference.rs"
  RustCrate* = "core"

import std/[algorithm, tables]

import core/matrix/state_res/resolve/types

proc authDifference*(authSets: openArray[AuthSet]): seq[EventId] =
  result = @[]
  if authSets.len == 0:
    return

  var counts = initTable[EventId, int]()
  for authSet in authSets:
    for id in sortedEventIds(authSet):
      counts[id] = counts.getOrDefault(id, 0) + 1

  for id, count in counts:
    if count < authSets.len:
      result.add(id)
  result.sort(system.cmp[string])

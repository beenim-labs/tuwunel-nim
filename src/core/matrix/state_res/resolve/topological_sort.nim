const
  RustPath* = "core/matrix/state_res/resolve/topological_sort.rs"
  RustCrate* = "core"

import std/[algorithm, sets, tables]

import core/matrix/state_res/resolve/types

type
  TieBreakerInfo* = object
    powerLevel*: int
    originServerTs*: int64

  TopologicalSortResult* = tuple[ok: bool, eventIds: seq[EventId], message: string]

proc compareCandidate(a, b: EventId; info: Table[EventId, TieBreakerInfo]): int =
  let aInfo = info[a]
  let bInfo = info[b]
  result = system.cmp(bInfo.powerLevel, aInfo.powerLevel)
  if result == 0:
    result = system.cmp(aInfo.originServerTs, bInfo.originServerTs)
  if result == 0:
    result = system.cmp(a, b)

proc removeReference(references: var ReferencedIds; eventId: EventId) =
  var kept: ReferencedIds = @[]
  for reference in references:
    if reference != eventId:
      kept.add(reference)
  references = kept

proc topologicalSort*(
  graph: EventGraph;
  info: Table[EventId, TieBreakerInfo]
): TopologicalSortResult =
  var working = graph
  var incoming = initTable[EventId, seq[EventId]]()

  for eventId, references in graph:
    if not info.hasKey(eventId):
      return (false, @[], "missing topological sort info for " & eventId)
    for reference in references:
      if not graph.hasKey(reference):
        return (false, @[], "graph references unknown event " & reference)
      if not incoming.hasKey(reference):
        incoming[reference] = @[]
      if eventId notin incoming[reference]:
        incoming[reference].add(eventId)

  for eventId in incoming.keys:
    incoming[eventId].sort(system.cmp[string])

  var horizon: seq[EventId] = @[]
  for eventId, references in graph:
    if references.len == 0:
      horizon.add(eventId)

  var processed = initHashSet[EventId]()
  var sorted: seq[EventId] = @[]
  while horizon.len > 0:
    horizon.sort(proc(a, b: EventId): int = compareCandidate(a, b, info))
    let eventId = horizon[0]
    horizon.delete(0)
    if eventId in processed:
      continue
    processed.incl(eventId)
    sorted.add(eventId)

    if incoming.hasKey(eventId):
      for parentId in incoming[eventId]:
        if not working.hasKey(parentId):
          continue
        working[parentId].removeReference(eventId)
        if working[parentId].len == 0 and parentId notin processed and parentId notin horizon:
          horizon.add(parentId)

  if sorted.len != graph.len:
    return (false, sorted, "graph contains a cycle or unresolved reference")
  (true, sorted, "")

## event_handler/fetch_prev — service module.
##
## Ported from Rust service/rooms/event_handler/fetch_prev.rs
##
## Fetches and processes missing prev (previous) events for an incoming
## federation PDU. Builds a dependency graph of prev events and returns
## them in topologically sorted order for sequential processing.

import std/[options, json, tables, strutils, logging, sets, sequtils, algorithm]
import ./mod as event_handler_mod
import ./fetch_auth

const
  RustPath* = "service/rooms/event_handler/fetch_prev.rs"
  RustCrate* = "service"

type
  EventIdInfo* = Table[string, tuple[pdu: JsonNode, json: JsonNode]]

proc fetchPrev*(self: Service; origin: string; roomId: string;
                initialSet: seq[string]; roomVersion: string;
                firstTsInRoom: int64):
    tuple[sorted: seq[string], info: EventIdInfo] =
  ## Ported from `fetch_prev`.
  ##
  ## Fetches missing prev events, builds a dependency graph, and returns
  ## events in topologically sorted order with their associated data.

  # Initialize work queue with initial prev event IDs
  type WorkItem = tuple[eventId: string, authResult: seq[FetchedPdu]]
  var todoStack: seq[WorkItem] = @[]

  for eventId in initialSet:
    let fetched = self.fetchAuth(origin, roomId, @[eventId], roomVersion)
    todoStack.add((eventId: eventId, authResult: fetched))

  var amount = 0
  var eventidInfo: EventIdInfo = initTable[string, tuple[pdu: JsonNode, json: JsonNode]]()
  var graph: Table[string, HashSet[string]] = initTable[string, HashSet[string]]()

  # In real impl: maxFetchPrevEvents from config
  let limit = 100  # placeholder config value

  var idx = 0
  while idx < todoStack.len:
    let (prevEventId, outlier) = todoStack[idx]
    inc idx

    if outlier.len == 0:
      # Fetch and handle failed
      graph[prevEventId] = initHashSet[string]()
      continue

    let (pdu, jsonOpt) = outlier[0]

    # Verify room ID matches
    let pduRoomId = pdu.getOrDefault("room_id").getStr("")
    checkRoomId(roomId, pduRoomId, prevEventId)

    if amount > limit:
      debug "fetch_prev: max prev event limit reached: ", limit
      graph[prevEventId] = initHashSet[string]()
      continue

    # Get the JSON — either from the fetch result or from outlier storage
    var json = if jsonOpt.isSome: jsonOpt.get()
               else: pdu  # fallback
    # In real impl: check self.services.timeline.getOutlierPduJson(prevEventId)

    # Check timestamp - skip events older than room's first event
    let originServerTs = pdu.getOrDefault("origin_server_ts").getBiggestInt(0)
    if originServerTs > firstTsInRoom:
      amount += 1

      # Add prev_events of this event to the work queue
      let prevEvents = pdu.getOrDefault("prev_events")
      if prevEvents.kind == JArray:
        var prevIds = initHashSet[string]()
        for pe in prevEvents:
          if pe.kind == JString:
            let peId = pe.getStr()
            prevIds.incl(peId)
            if peId notin graph:
              let fetched = self.fetchAuth(origin, roomId, @[peId], roomVersion)
              todoStack.add((eventId: peId, authResult: fetched))

        graph[prevEventId] = prevIds
      else:
        graph[prevEventId] = initHashSet[string]()
    else:
      # Time based check failed
      graph[prevEventId] = initHashSet[string]()

    eventidInfo[prevEventId] = (pdu: pdu, json: json)

  # Topologically sort the dependency graph
  # In real impl: stateRes.topologicalSort(graph, eventFetch)
  # Simple topological sort: events with no dependencies first
  var sorted: seq[string] = @[]
  var visited = initHashSet[string]()
  var temp = initHashSet[string]()

  proc visit(node: string) =
    if node in visited:
      return
    if node in temp:
      return  # cycle detected, skip
    temp.incl(node)
    if node in graph:
      for dep in graph[node]:
        visit(dep)
    temp.excl(node)
    visited.incl(node)
    sorted.add(node)

  for key in graph.keys:
    visit(key)

  (sorted: sorted, info: eventidInfo)
## event_handler/fetch_auth — service module.
##
## Ported from Rust service/rooms/event_handler/fetch_auth.rs
##
## Finds and authenticates events and their auth chains.
## Looks up events locally first, then fetches over federation.
## Returns validated PDUs with optional raw JSON for federation-fetched events.

import std/[options, json, tables, strutils, logging, sets, deques, sequtils]
import ./mod as event_handler_mod

const
  RustPath* = "service/rooms/event_handler/fetch_auth.rs"
  RustCrate* = "service"

type
  FetchedPdu* = tuple[pdu: JsonNode, json: Option[JsonNode]]
  AuthChainResult* = tuple[eventId: string, localPdu: Option[JsonNode],
                           eventsReverse: seq[tuple[id: string, value: JsonNode]]]

proc fetchAuthChain*(self: Service; origin: string; roomId: string;
                     eventId: string; roomVersion: string): AuthChainResult =
  ## Ported from `fetch_auth_chain`.
  ##
  ## For a single event:
  ##   a. Look in the main timeline (pduid_pdu tree)
  ##   b. Look at outlier pdu tree
  ##   c. Ask origin server over federation
  ## Also handles the auth chain to avoid stack overflow in handle_outlier_pdu.

  # a. Look in the main timeline / b. Look at outlier pdu tree
  # In real impl: self.services.timeline.getPdu(eventId)
  let localPdu = none(JsonNode)  # placeholder for local lookup

  if localPdu.isSome:
    debug "fetch_auth_chain: found ", eventId, " in database"
    return (eventId: eventId, localPdu: localPdu, eventsReverse: @[])

  # c. Ask origin server over federation
  # Walk the auth chain breadth-first to avoid recursion
  var todoAuthEvents = initDeque[string]()
  todoAuthEvents.addLast(eventId)
  var eventsInReverseOrder: seq[tuple[id: string, value: JsonNode]] = @[]
  var eventsAll = initHashSet[string]()

  while todoAuthEvents.len > 0:
    let nextId = todoAuthEvents.popFirst()

    if nextId in eventsAll:
      continue

    # Check back-off
    if self.isBackedOff(nextId, initDuration(minutes = 2), initDuration(hours = 8)):
      debug "fetch_auth_chain: backed off from ", nextId
      continue

    # Check if already in database
    # In real impl: self.services.timeline.pduExists(nextId)
    let existsLocally = false  # placeholder
    if existsLocally:
      debug "fetch_auth_chain: ", nextId, " found in database"
      continue

    # Fetch over federation
    debug "fetch_auth_chain: fetching ", nextId, " over federation"
    # In real impl: self.services.federation.execute(origin, getEvent request)
    # For now, simulate a failed fetch to demonstrate back-off logic
    let fetchResult = none(JsonNode)  # placeholder

    if fetchResult.isNone:
      debug "fetch_auth_chain: failed to fetch ", nextId, ", backing off"
      self.backOff(nextId)
      continue

    let res = fetchResult.get()
    debug "fetch_auth_chain: got ", nextId, " over federation"

    # In real impl: genEventIdCanonicalJson(res.pdu, roomVersion)
    # Verify calculated event ID matches
    let calculatedEventId = nextId  # placeholder
    if calculatedEventId != nextId:
      warn "Server didn't return event id we requested: ", nextId,
           ", got ", calculatedEventId

    # Extract auth_events and add to queue
    let authEvents = res.getOrDefault("auth_events")
    if authEvents.kind == JArray:
      for authEvent in authEvents:
        if authEvent.kind == JString:
          todoAuthEvents.addLast(authEvent.getStr())
    else:
      warn "fetch_auth_chain: auth event list invalid"

    eventsInReverseOrder.add((id: nextId, value: res))
    eventsAll.incl(nextId)

  (eventId: eventId, localPdu: none(JsonNode), eventsReverse: eventsInReverseOrder)


proc fetchAuth*(self: Service; origin: string; roomId: string;
                eventIds: seq[string]; roomVersion: string): seq[FetchedPdu] =
  ## Ported from `fetch_auth`.
  ##
  ## For each event ID, fetches its auth chain, then processes all events
  ## through handle_outlier_pdu to validate and persist them.

  var result: seq[FetchedPdu] = @[]

  # Fetch auth chains for all events
  var allChains: seq[AuthChainResult] = @[]
  for eventId in eventIds:
    allChains.add(self.fetchAuthChain(origin, roomId, eventId, roomVersion))

  for chain in allChains:
    let (id, localPdu, eventsReverse) = chain

    # a/b. If found locally, add it
    if localPdu.isSome:
      result.add((pdu: localPdu.get(), json: none(JsonNode)))

    # Process fetched events in reverse order (chronological)
    for i in countdown(eventsReverse.high, 0):
      let (nextId, value) = eventsReverse[i]

      # Check back-off
      if self.isBackedOff(nextId, initDuration(minutes = 5), initDuration(hours = 24)):
        continue

      # In real impl: self.handleOutlierPdu(origin, roomId, nextId, value, roomVersion, true)
      # On success: add to result if nextId == id
      # On failure: self.backOff(nextId)

      # Placeholder: attempt validation
      try:
        var valueJson = value
        # In real impl: full outlier handling
        if nextId == id:
          result.add((pdu: valueJson, json: some(value)))
      except:
        warn "fetch_auth: authentication of event ", nextId, " failed"
        self.backOff(nextId)

  result
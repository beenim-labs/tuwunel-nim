const
  RustPath* = "core/matrix/state_res/resolve/iterative_auth_check.rs"
  RustCrate* = "core"

import std/[json, tables]

import core/matrix/state_res/event_auth
import core/matrix/state_res/event_format
import core/matrix/state_res/resolve/types
import core/matrix/state_res/rules

type
  IterativeAuthCheckResult* = tuple[
    ok: bool,
    state: StateMap,
    rejected: seq[EventId],
    message: string,
  ]

proc authEventsFor(event: JsonNode; eventsById: Table[EventId, JsonNode]): seq[JsonNode] =
  result = @[]
  for authEventId in event.authEvents():
    if eventsById.hasKey(authEventId):
      result.add(eventsById[authEventId])

proc iterativeAuthCheck*(
  eventIds: openArray[EventId];
  initialState: StateMap;
  eventsById: Table[EventId, JsonNode];
  rules = authorizationRules()
): IterativeAuthCheckResult =
  result = (
    ok: true,
    state: initialState,
    rejected: @[],
    message: "",
  )

  for eventId in eventIds:
    if not eventsById.hasKey(eventId):
      result.ok = false
      result.rejected.add(eventId)
      result.message = "event not found: " & eventId
      continue

    let event = eventsById[eventId]
    let authCheck = checkStateIndependentAuthTypes(event, event.authEventsFor(eventsById), rules)
    if not authCheck.ok:
      result.rejected.add(eventId)
      continue

    let key = event.typeStateKey()
    if key.ok:
      result.state[key.key] = eventId

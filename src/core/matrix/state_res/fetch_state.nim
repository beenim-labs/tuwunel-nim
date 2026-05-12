const
  RustPath* = "core/matrix/state_res/fetch_state.rs"
  RustCrate* = "core"

import std/[json, options, tables]

import core/matrix/event/state_key
import core/matrix/state_res/events/[
  create,
  join_rules,
  member,
  power_levels,
  third_party_invite,
]
import core/matrix/state_res/resolve/types

type
  FetchState* = object
    state*: StateMap
    eventsById*: Table[EventId, JsonNode]

  FetchEventResult* = tuple[ok: bool, event: JsonNode, message: string]

proc fetchState*(state: StateMap; eventsById: Table[EventId, JsonNode]): FetchState =
  FetchState(state: state, eventsById: eventsById)

proc stateEvent*(
  fetch: FetchState;
  eventType, stateKeyValue: string
): FetchEventResult =
  let key = typeStateKey(eventType, stateKeyValue)
  if not fetch.state.hasKey(key):
    return (false, newJObject(), "state not found: (" & eventType & "," & stateKeyValue & ")")
  let eventId = fetch.state[key]
  if not fetch.eventsById.hasKey(eventId):
    return (false, newJObject(), "event not found: " & eventId)
  (true, fetch.eventsById[eventId], "")

proc roomCreateEvent*(
  fetch: FetchState
): tuple[ok: bool, event: RoomCreateEvent, message: string] =
  let event = fetch.stateEvent("m.room.create", "")
  if not event.ok:
    return (false, RoomCreateEvent(), "no `m.room.create` event in current state: " & event.message)
  (true, create.roomCreateEvent(event.event), "")

proc userMembership*(
  fetch: FetchState;
  userId: string
): tuple[ok: bool, state: MembershipState, value: string, message: string] =
  let event = fetch.stateEvent("m.room.member", userId)
  if not event.ok:
    return (true, msLeave, "leave", "")
  let membership = member.roomMemberEvent(event.event).membership()
  if not membership.ok:
    return (false, msCustom, "", membership.message)
  membership

proc roomPowerLevelsEvent*(fetch: FetchState): Option[RoomPowerLevelsEvent] =
  let event = fetch.stateEvent("m.room.power_levels", "")
  if event.ok:
    some(power_levels.roomPowerLevelsEvent(event.event))
  else:
    none(RoomPowerLevelsEvent)

proc joinRule*(
  fetch: FetchState
): tuple[ok: bool, rule: JoinRule, message: string] =
  let event = fetch.stateEvent("m.room.join_rules", "")
  if not event.ok:
    return (false, JoinRule(), "no `m.room.join_rules` event in current state: " & event.message)
  join_rules.roomJoinRulesEvent(event.event).joinRule()

proc roomThirdPartyInviteEvent*(
  fetch: FetchState;
  token: string
): Option[RoomThirdPartyInviteEvent] =
  let event = fetch.stateEvent("m.room.third_party_invite", token)
  if event.ok:
    some(third_party_invite.roomThirdPartyInviteEvent(event.event))
  else:
    none(RoomThirdPartyInviteEvent)

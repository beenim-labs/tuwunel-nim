const
  RustPath* = "core/matrix/state_res/events/power_levels.rs"
  RustCrate* = "core"

import std/[algorithm, json, options, strutils]

import core/matrix/state_res/json_helpers
import core/matrix/state_res/rules

const
  DefaultCreatorPowerLevel* = 100
  InfinitePowerLevel* = high(int)

type
  RoomPowerLevelsIntField* = enum
    plUsersDefault,
    plEventsDefault,
    plStateDefault,
    plBan,
    plRedact,
    plKick,
    plInvite

  RoomPowerLevelsEvent* = object
    event*: JsonNode

  IntFieldResult* = tuple[ok: bool, found: bool, value: int, message: string]
  IntMapResult* = tuple[ok: bool, values: seq[tuple[key: string, value: int]], message: string]
  PowerLevelResult* = tuple[ok: bool, value: int, infinite: bool, message: string]

const AllRoomPowerLevelsIntFields* = [
  plUsersDefault,
  plEventsDefault,
  plStateDefault,
  plBan,
  plRedact,
  plKick,
  plInvite,
]

proc roomPowerLevelsEvent*(event: JsonNode): RoomPowerLevelsEvent =
  RoomPowerLevelsEvent(event: if event.isNil: newJObject() else: event)

proc content(event: RoomPowerLevelsEvent): JsonNode =
  if event.event.isNil or event.event.kind != JObject:
    return newJObject()
  event.event.jsonContent()

proc asStr*(field: RoomPowerLevelsIntField): string =
  case field
  of plUsersDefault: "users_default"
  of plEventsDefault: "events_default"
  of plStateDefault: "state_default"
  of plBan: "ban"
  of plRedact: "redact"
  of plKick: "kick"
  of plInvite: "invite"

proc defaultValue*(field: RoomPowerLevelsIntField): int =
  case field
  of plUsersDefault, plEventsDefault, plInvite:
    0
  of plStateDefault, plBan, plRedact, plKick:
    50

proc parsePowerLevel(value: JsonNode; rules: AuthorizationRules): tuple[ok: bool, value: int, message: string] =
  if value.kind == JInt:
    return (true, value.getInt(), "")
  if not rules.integerPowerLevels and value.kind == JString:
    try:
      return (true, parseInt(value.getStr()), "")
    except ValueError as err:
      return (false, 0, err.msg)
  (false, 0, "expected integer power level")

proc getAsInt*(
  event: RoomPowerLevelsEvent;
  field: RoomPowerLevelsIntField;
  rules = authorizationRules()
): IntFieldResult =
  let content = event.content()
  let value = content.jsonField(field.asStr())
  if value.kind == JNull:
    return (true, false, 0, "")
  let parsed = parsePowerLevel(value, rules)
  if not parsed.ok:
    return (false, true, 0, "unexpected format of `" & field.asStr() & "` in `m.room.power_levels`: " & parsed.message)
  (true, true, parsed.value, "")

proc getAsIntOrDefault*(
  event: RoomPowerLevelsEvent;
  field: RoomPowerLevelsIntField;
  rules = authorizationRules()
): tuple[ok: bool, value: int, message: string] =
  let parsed = event.getAsInt(field, rules)
  if not parsed.ok:
    return (false, 0, parsed.message)
  if parsed.found:
    (true, parsed.value, "")
  else:
    (true, field.defaultValue(), "")

proc getAsIntMap*(
  event: RoomPowerLevelsEvent;
  field: string;
  rules = authorizationRules()
): IntMapResult =
  let content = event.content()
  let value = content.jsonField(field)
  if value.kind == JNull:
    return (true, @[], "")
  if value.kind != JObject:
    return (false, @[], "unexpected format of `" & field & "` in `m.room.power_levels`")

  var values: seq[tuple[key: string, value: int]] = @[]
  for key, item in value:
    let parsed = parsePowerLevel(item, rules)
    if not parsed.ok:
      return (false, @[], "unexpected format of `" & field & "." & key & "` in `m.room.power_levels`: " & parsed.message)
    values.add((key, parsed.value))
  values.sort(proc(a, b: tuple[key: string, value: int]): int = system.cmp(a.key, b.key))
  (true, values, "")

proc events*(event: RoomPowerLevelsEvent; rules = authorizationRules()): IntMapResult =
  event.getAsIntMap("events", rules)

proc notifications*(event: RoomPowerLevelsEvent; rules = authorizationRules()): IntMapResult =
  event.getAsIntMap("notifications", rules)

proc users*(event: RoomPowerLevelsEvent; rules = authorizationRules()): IntMapResult =
  event.getAsIntMap("users", rules)

proc valueForKey(values: openArray[tuple[key: string, value: int]]; key: string): Option[int] =
  for entry in values:
    if entry.key == key:
      return some(entry.value)
  none(int)

proc userPowerLevel*(
  event: RoomPowerLevelsEvent;
  userId: string;
  rules = authorizationRules()
): PowerLevelResult =
  let users = event.users(rules)
  if not users.ok:
    return (false, 0, false, users.message)
  let userValue = valueForKey(users.values, userId)
  if userValue.isSome:
    return (true, userValue.get(), false, "")
  let defaultValue = event.getAsIntOrDefault(plUsersDefault, rules)
  if not defaultValue.ok:
    return (false, 0, false, defaultValue.message)
  (true, defaultValue.value, false, "")

proc userPowerLevel*(
  event: Option[RoomPowerLevelsEvent];
  userId: string;
  creators: openArray[string];
  rules = authorizationRules()
): PowerLevelResult =
  if rules.explicitlyPrivilegeRoomCreators and userId in creators:
    return (true, InfinitePowerLevel, true, "")
  if event.isSome:
    return event.get().userPowerLevel(userId, rules)
  let powerLevel =
    if userId in creators:
      DefaultCreatorPowerLevel
    else:
      plUsersDefault.defaultValue()
  (true, powerLevel, false, "")

proc eventPowerLevel*(
  event: RoomPowerLevelsEvent;
  eventType: string;
  stateKey: Option[string];
  rules = authorizationRules()
): tuple[ok: bool, value: int, message: string] =
  let events = event.events(rules)
  if not events.ok:
    return (false, 0, events.message)
  let eventValue = valueForKey(events.values, eventType)
  if eventValue.isSome:
    return (true, eventValue.get(), "")
  let defaultField =
    if stateKey.isSome:
      plStateDefault
    else:
      plEventsDefault
  event.getAsIntOrDefault(defaultField, rules)

proc eventPowerLevel*(
  event: Option[RoomPowerLevelsEvent];
  eventType: string;
  stateKey: Option[string];
  rules = authorizationRules()
): tuple[ok: bool, value: int, message: string] =
  if event.isSome:
    event.get().eventPowerLevel(eventType, stateKey, rules)
  else:
    let defaultField =
      if stateKey.isSome:
        plStateDefault
      else:
        plEventsDefault
    (true, defaultField.defaultValue(), "")

proc intFieldsMap*(
  event: RoomPowerLevelsEvent;
  rules = authorizationRules()
): tuple[ok: bool, values: seq[tuple[field: RoomPowerLevelsIntField, value: int]], message: string] =
  result = (true, @[], "")
  for field in AllRoomPowerLevelsIntFields:
    let parsed = event.getAsInt(field, rules)
    if not parsed.ok:
      return (false, @[], parsed.message)
    if parsed.found:
      result.values.add((field, parsed.value))

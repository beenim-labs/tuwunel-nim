const
  RustPath* = "core/matrix/state_res/events/create.rs"
  RustCrate* = "core"

import std/[algorithm, json]

import core/matrix/state_res/json_helpers
import core/matrix/state_res/rules

type
  RoomCreateEvent* = object
    event*: JsonNode

proc roomCreateEvent*(event: JsonNode): RoomCreateEvent =
  RoomCreateEvent(event: if event.isNil: newJObject() else: event)

proc content(event: RoomCreateEvent): JsonNode =
  if event.event.isNil or event.event.kind != JObject:
    return newJObject()
  event.event.jsonContent()

proc sender*(event: RoomCreateEvent): string =
  if event.event.isNil or event.event.kind != JObject:
    return ""
  event.event.jsonField("sender").getStr("")

proc roomVersion*(event: RoomCreateEvent): tuple[ok: bool, value: string, message: string] =
  let content = event.content()
  let value = content.jsonField("room_version")
  if value.kind == JNull:
    return (true, "1", "")
  if value.kind != JString:
    return (false, "", "invalid `room_version` field in `m.room.create` event")
  (true, value.getStr("1"), "")

proc federate*(event: RoomCreateEvent): tuple[ok: bool, value: bool, message: string] =
  let content = event.content()
  let value = content.jsonField("m.federate")
  if value.kind == JNull:
    return (true, true, "")
  if value.kind != JBool:
    return (false, false, "invalid `m.federate` field in `m.room.create` event")
  (true, value.getBool(true), "")

proc creator*(
  event: RoomCreateEvent;
  rules = authorizationRules()
): tuple[ok: bool, value: string, message: string] =
  if rules.useRoomCreateSender:
    let sender = event.sender()
    if sender.len == 0:
      return (false, "", "missing `sender` field in `m.room.create` event")
    return (true, sender, "")

  let value = event.content().jsonField("creator")
  if value.kind != JString or value.getStr("").len == 0:
    return (false, "", "missing or invalid `creator` field in `m.room.create` event")
  (true, value.getStr(), "")

proc additionalCreators*(
  event: RoomCreateEvent;
  rules = authorizationRules()
): tuple[ok: bool, values: seq[string], message: string] =
  if not rules.additionalRoomCreators:
    return (true, @[], "")
  let value = event.content().jsonField("additional_creators")
  if value.kind == JNull:
    return (true, @[], "")
  if value.kind != JArray:
    return (false, @[], "invalid `additional_creators` field in `m.room.create` event")

  var creators: seq[string] = @[]
  for item in value:
    if item.kind != JString or item.getStr("").len == 0:
      return (false, @[], "invalid `additional_creators` entry in `m.room.create` event")
    creators.add(item.getStr())
  creators.sort(system.cmp[string])
  var deduped: seq[string] = @[]
  for userId in creators:
    if deduped.len == 0 or deduped[^1] != userId:
      deduped.add(userId)
  (true, deduped, "")

proc creators*(
  event: RoomCreateEvent;
  rules = authorizationRules()
): tuple[ok: bool, values: seq[string], message: string] =
  let creator = event.creator(rules)
  if not creator.ok:
    return (false, @[], creator.message)
  let additional = event.additionalCreators(rules)
  if not additional.ok:
    return (false, @[], additional.message)
  result = (true, @[creator.value], "")
  for userId in additional.values:
    result.values.add(userId)

proc hasCreator*(event: RoomCreateEvent): tuple[ok: bool, value: bool, message: string] =
  let content = event.content()
  (true, content.hasKey("creator"), "")

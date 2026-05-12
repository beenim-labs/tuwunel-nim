const
  RustPath* = "core/matrix/state_res/event_format.rs"
  RustCrate* = "core"

import std/[json, options]

import core/matrix/event/state_key
import core/matrix/state_res/json_helpers

proc eventId*(event: JsonNode): string =
  event.jsonField("event_id").getStr("")

proc eventType*(event: JsonNode): string =
  event.jsonField("type").getStr("")

proc sender*(event: JsonNode): string =
  event.jsonField("sender").getStr("")

proc stateKey*(event: JsonNode): Option[string] =
  if event.isNil or event.kind != JObject or not event.hasKey("state_key"):
    return none(string)
  some(event["state_key"].getStr(""))

proc content*(event: JsonNode): JsonNode =
  event.jsonContent()

proc originServerTs*(event: JsonNode): int64 =
  event.jsonField("origin_server_ts").getInt(0).int64

proc typeStateKey*(event: JsonNode): tuple[ok: bool, key: TypeStateKey, message: string] =
  let eventType = event.eventType()
  if eventType.len == 0:
    return (false, typeStateKey("", ""), "event is missing `type`")
  let stateKeyValue = event.stateKey()
  if stateKeyValue.isNone:
    return (false, typeStateKey("", ""), "event is missing `state_key`")
  (true, typeStateKey(eventType, stateKeyValue.get()), "")

proc isTypeAndStateKey*(event: JsonNode; eventTypeValue, stateKeyValue: string): bool =
  let parsed = event.typeStateKey()
  parsed.ok and parsed.key == typeStateKey(eventTypeValue, stateKeyValue)

proc eventIdFromReference(reference: JsonNode): string =
  if reference.kind == JString:
    return reference.getStr("")
  if reference.kind == JArray and reference.len > 0:
    return reference[0].getStr("")
  ""

proc eventReferences*(event: JsonNode; field: string): seq[string] =
  result = @[]
  let value = event.jsonField(field)
  if value.kind != JArray:
    return
  for item in value:
    let eventId = eventIdFromReference(item)
    if eventId.len > 0:
      result.add(eventId)

proc authEvents*(event: JsonNode): seq[string] =
  event.eventReferences("auth_events")

proc prevEvents*(event: JsonNode): seq[string] =
  event.eventReferences("prev_events")

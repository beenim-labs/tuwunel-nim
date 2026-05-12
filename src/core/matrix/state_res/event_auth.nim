const
  RustPath* = "core/matrix/state_res/event_auth.rs"
  RustCrate* = "core"

import std/json

import core/matrix/event/state_key
import core/matrix/state_res/event_auth/auth_types
import core/matrix/state_res/event_auth/room_member
import core/matrix/state_res/json_helpers
import core/matrix/state_res/rules

export auth_types, room_member

type
  AuthTypeCheck* = tuple[
    ok: bool,
    missing: seq[TypeStateKey],
    duplicate: seq[TypeStateKey],
    unexpected: seq[TypeStateKey],
    message: string,
  ]

proc authEventTypeStateKey*(event: JsonNode): tuple[ok: bool, key: TypeStateKey, message: string] =
  if event.isNil or event.kind != JObject:
    return (false, typeStateKey("", ""), "auth event must be an object")
  let eventType = event.jsonField("type").getStr("")
  if eventType.len == 0:
    return (false, typeStateKey("", ""), "auth event is missing `type`")
  if not event.hasKey("state_key"):
    return (false, typeStateKey("", ""), "auth event is missing `state_key`")
  (true, typeStateKey(eventType, event["state_key"].getStr("")), "")

proc containsKey(values: openArray[TypeStateKey]; key: TypeStateKey): bool =
  for value in values:
    if value == key:
      return true
  false

proc expectedAuthTypesForEvent*(
  event: JsonNode;
  rules = authorizationRules();
  alwaysCreate = false
): AuthTypesResult =
  authTypesForEvent(event, rules, alwaysCreate)

proc providedAuthEventTypes*(
  authEvents: openArray[JsonNode]
): tuple[ok: bool, values: AuthTypes, duplicate: AuthTypes, message: string] =
  var values: AuthTypes = @[]
  var duplicate: AuthTypes = @[]
  for event in authEvents:
    let parsed = authEventTypeStateKey(event)
    if not parsed.ok:
      return (false, @[], @[], parsed.message)
    if values.containsKey(parsed.key):
      if not duplicate.containsKey(parsed.key):
        duplicate.add(parsed.key)
    else:
      values.add(parsed.key)
  (true, values, duplicate, "")

proc checkStateIndependentAuthTypes*(
  event: JsonNode;
  authEvents: openArray[JsonNode];
  rules = authorizationRules();
  alwaysCreate = false
): AuthTypeCheck =
  let expected = expectedAuthTypesForEvent(event, rules, alwaysCreate)
  if not expected.ok:
    return (false, @[], @[], @[], expected.message)
  let provided = providedAuthEventTypes(authEvents)
  if not provided.ok:
    return (false, @[], @[], @[], provided.message)

  var missing: seq[TypeStateKey] = @[]
  for key in expected.authTypes:
    if not provided.values.containsKey(key):
      missing.add(key)

  var unexpected: seq[TypeStateKey] = @[]
  for key in provided.values:
    if not expected.authTypes.containsKey(key):
      unexpected.add(key)

  let ok = missing.len == 0 and provided.duplicate.len == 0 and unexpected.len == 0
  let message =
    if ok:
      ""
    else:
      "auth events do not match expected Matrix type/state-key selection"
  (ok, missing, provided.duplicate, unexpected, message)

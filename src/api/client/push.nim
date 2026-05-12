const
  RustPath* = "api/client/push.rs"
  RustCrate* = "api"

import std/[json, strutils]

type
  PushPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc pusherKey*(userId, appId, pushKey: string): string =
  userId & "\x1f" & appId & "\x1f" & pushKey

proc pushRuleKey*(userId, scope, kind, ruleId: string): string =
  userId & "\x1f" & scope & "\x1f" & kind & "\x1f" & ruleId

proc pushRuleKinds*(): seq[string] =
  @["override", "content", "room", "sender", "underride"]

proc isPushRuleKind*(kind: string): bool =
  kind in pushRuleKinds()

proc emptyPushRulesPayload*(): JsonNode =
  %*{
    "global": {
      "override": [],
      "content": [],
      "room": [],
      "sender": [],
      "underride": []
    }
  }

proc pushersPayload*(pushers: openArray[JsonNode]): JsonNode =
  var arr = newJArray()
  for pusher in pushers:
    arr.add(if pusher.isNil: newJObject() else: pusher.copy())
  %*{"pushers": arr}

proc pusherFromBody*(body: JsonNode): tuple[ok: bool, delete: bool, appId: string, pushKey: string, pusher: JsonNode, errcode: string, message: string] =
  if body.isNil or body.kind != JObject:
    return (false, false, "", "", newJObject(), "M_BAD_JSON", "Pusher body must be an object.")
  let appId = body{"app_id"}.getStr("")
  let pushKey = body{"pushkey"}.getStr("")
  if appId.len == 0 or pushKey.len == 0:
    return (false, false, "", "", newJObject(), "M_MISSING_PARAM", "app_id and pushkey are required.")
  if body.hasKey("kind") and body["kind"].kind == JNull:
    return (true, true, appId, pushKey, newJObject(), "", "")
  var pusher = body.copy()
  pusher["app_id"] = %appId
  pusher["pushkey"] = %pushKey
  if not pusher.hasKey("kind") or pusher["kind"].kind == JNull:
    pusher["kind"] = %"http"
  if not pusher.hasKey("app_display_name"):
    pusher["app_display_name"] = %""
  if not pusher.hasKey("device_display_name"):
    pusher["device_display_name"] = %""
  if not pusher.hasKey("lang"):
    pusher["lang"] = %"en"
  if not pusher.hasKey("data") or pusher["data"].kind != JObject:
    pusher["data"] = newJObject()
  (true, false, appId, pushKey, pusher, "", "")

proc normalizePushRule*(rule: JsonNode; ruleId, kind: string; existing: JsonNode = nil): JsonNode =
  result = newJObject()
  if not existing.isNil and existing.kind == JObject:
    for key, value in existing:
      result[key] = if value.isNil: newJNull() else: value.copy()
  if not rule.isNil and rule.kind == JObject:
    for key, value in rule:
      result[key] = if value.isNil: newJNull() else: value.copy()
  result["rule_id"] = %ruleId
  if not result.hasKey("default"):
    result["default"] = %false
  if not result.hasKey("enabled"):
    result["enabled"] = %true
  if not result.hasKey("actions") or result["actions"].kind != JArray:
    result["actions"] = newJArray()
  if kind == "content" and not result.hasKey("pattern"):
    result["pattern"] = %""
  if kind in ["override", "underride"] and
      (not result.hasKey("conditions") or result["conditions"].kind != JArray):
    result["conditions"] = newJArray()

proc pushRulePathPolicy*(scope, kind, ruleId: string): PushPolicyResult =
  if scope.len == 0 or kind.len == 0 or ruleId.len == 0 or not isPushRuleKind(kind):
    return (false, "M_INVALID_PARAM", "Invalid push rule path.")
  (true, "", "")

proc pushRuleBodyPolicy*(body: JsonNode): PushPolicyResult =
  if body.isNil or body.kind != JObject:
    return (false, "M_BAD_JSON", "Push rule body must be an object.")
  (true, "", "")

proc pushRuleAttrPayload*(rule: JsonNode; attr: string): tuple[ok: bool, payload: JsonNode] =
  if rule.isNil or rule.kind != JObject:
    return (false, newJObject())
  case attr
  of "":
    (true, rule.copy())
  of "enabled":
    (true, %*{"enabled": rule{"enabled"}.getBool(true)})
  of "actions":
    (true, %*{"actions": if rule{"actions"}.kind == JArray: rule["actions"].copy() else: newJArray()})
  else:
    (false, newJObject())

proc updatePushRuleAttr*(rule: JsonNode; ruleId, kind, attr: string; body: JsonNode): tuple[ok: bool, payload: JsonNode, errcode: string, message: string] =
  var updated = if rule.isNil: normalizePushRule(newJObject(), ruleId, kind) else: rule.copy()
  case attr
  of "enabled":
    if body.isNil or body.kind != JObject or not body.hasKey("enabled") or body["enabled"].kind != JBool:
      return (false, newJObject(), "M_BAD_JSON", "enabled must be a boolean.")
    updated["enabled"] = %body["enabled"].getBool(false)
  of "actions":
    if body.isNil or body.kind != JObject or not body.hasKey("actions") or body["actions"].kind != JArray:
      return (false, newJObject(), "M_BAD_JSON", "actions must be an array.")
    updated["actions"] = body["actions"].copy()
  else:
    return (false, newJObject(), "M_INVALID_PARAM", "Unsupported push rule attribute.")
  (true, normalizePushRule(updated, ruleId, kind), "", "")

proc notificationLimit*(limit: int): int =
  max(1, min(100, limit))

proc notificationOnlyHighlight*(only: string): bool =
  only.toLowerAscii().contains("highlight")

proc pushWriteResponse*(): JsonNode =
  newJObject()

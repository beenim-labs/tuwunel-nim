const
  RustPath* = "core/matrix/state_res/events/join_rules.rs"
  RustCrate* = "core"

import std/json

import core/matrix/state_res/json_helpers

type
  JoinRuleKind* = enum
    jrPublic,
    jrInvite,
    jrKnock,
    jrRestricted,
    jrKnockRestricted,
    jrCustom

  JoinRule* = object
    kind*: JoinRuleKind
    custom*: string

  RoomJoinRulesEvent* = object
    event*: JsonNode

proc roomJoinRulesEvent*(event: JsonNode): RoomJoinRulesEvent =
  RoomJoinRulesEvent(event: if event.isNil: newJObject() else: event)

proc parseJoinRule*(value: string): JoinRule =
  case value
  of "public":
    JoinRule(kind: jrPublic)
  of "invite":
    JoinRule(kind: jrInvite)
  of "knock":
    JoinRule(kind: jrKnock)
  of "restricted":
    JoinRule(kind: jrRestricted)
  of "knock_restricted":
    JoinRule(kind: jrKnockRestricted)
  else:
    JoinRule(kind: jrCustom, custom: value)

proc `$`*(rule: JoinRule): string =
  case rule.kind
  of jrPublic: "public"
  of jrInvite: "invite"
  of jrKnock: "knock"
  of jrRestricted: "restricted"
  of jrKnockRestricted: "knock_restricted"
  of jrCustom: rule.custom

proc joinRule*(event: RoomJoinRulesEvent): tuple[ok: bool, rule: JoinRule, message: string] =
  if event.event.isNil or event.event.kind != JObject:
    return (false, JoinRule(), "event must be an object")
  let content = event.event.jsonContent()
  if content.kind != JObject:
    return (false, JoinRule(), "missing content in `m.room.join_rules` event")
  let value = content.jsonField("join_rule")
  if value.kind != JString or value.getStr("").len == 0:
    return (false, JoinRule(), "missing or invalid `join_rule` field in `m.room.join_rules` event")
  (true, parseJoinRule(value.getStr()), "")

proc isRestrictedLike*(rule: JoinRule): bool =
  rule.kind in {jrRestricted, jrKnockRestricted}

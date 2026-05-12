const
  RustPath* = "core/matrix/state_res/events/member.rs"
  RustCrate* = "core"

import std/[json, options]

import core/matrix/server_signing
import core/matrix/state_res/json_helpers

type
  MembershipState* = enum
    msBan,
    msInvite,
    msJoin,
    msKnock,
    msLeave,
    msCustom

  ThirdPartyInvite* = object
    signed*: JsonNode

  RoomMemberEventContent* = object
    content*: JsonNode

  RoomMemberEvent* = object
    event*: JsonNode

proc roomMemberEvent*(event: JsonNode): RoomMemberEvent =
  RoomMemberEvent(event: if event.isNil: newJObject() else: event)

proc roomMemberEventContent*(content: JsonNode): RoomMemberEventContent =
  RoomMemberEventContent(content: if content.isNil: newJObject() else: content)

proc content(event: RoomMemberEvent): JsonNode =
  if event.event.isNil or event.event.kind != JObject:
    return newJObject()
  event.event.jsonContent()

proc parseMembershipState*(value: string): MembershipState =
  case value
  of "ban":
    msBan
  of "invite":
    msInvite
  of "join":
    msJoin
  of "knock":
    msKnock
  of "leave":
    msLeave
  else:
    msCustom

proc `$`*(state: MembershipState): string =
  case state
  of msBan: "ban"
  of msInvite: "invite"
  of msJoin: "join"
  of msKnock: "knock"
  of msLeave: "leave"
  of msCustom: "custom"

proc membership*(
  content: RoomMemberEventContent
): tuple[ok: bool, state: MembershipState, value: string, message: string] =
  if content.content.kind != JObject:
    return (false, msCustom, "", "content must be an object")
  let value = content.content.jsonField("membership")
  if value.kind != JString or value.getStr("").len == 0:
    return (false, msCustom, "", "missing or invalid `membership` field in `m.room.member` event")
  let raw = value.getStr()
  (true, parseMembershipState(raw), raw, "")

proc membership*(
  event: RoomMemberEvent
): tuple[ok: bool, state: MembershipState, value: string, message: string] =
  roomMemberEventContent(event.content()).membership()

proc joinAuthorisedViaUsersServer*(
  content: RoomMemberEventContent
): tuple[ok: bool, value: Option[string], message: string] =
  if content.content.kind != JObject:
    return (false, none(string), "content must be an object")
  let value = content.content.jsonField("join_authorised_via_users_server")
  if value.kind == JNull:
    return (true, none(string), "")
  if value.kind != JString or value.getStr("").len == 0:
    return (false, none(string), "invalid `join_authorised_via_users_server` field in `m.room.member` event")
  (true, some(value.getStr()), "")

proc joinAuthorisedViaUsersServer*(
  event: RoomMemberEvent
): tuple[ok: bool, value: Option[string], message: string] =
  roomMemberEventContent(event.content()).joinAuthorisedViaUsersServer()

proc thirdPartyInvite*(
  content: RoomMemberEventContent
): tuple[ok: bool, invite: Option[ThirdPartyInvite], message: string] =
  if content.content.kind != JObject:
    return (false, none(ThirdPartyInvite), "content must be an object")
  let value = content.content.jsonField("third_party_invite")
  if value.kind == JNull:
    return (true, none(ThirdPartyInvite), "")
  if value.kind != JObject:
    return (false, none(ThirdPartyInvite), "invalid `third_party_invite` field in `m.room.member` event")
  let signed = value.jsonField("signed")
  if signed.kind != JObject:
    return (false, none(ThirdPartyInvite), "missing or invalid `third_party_invite.signed` field in `m.room.member` event")
  (true, some(ThirdPartyInvite(signed: signed)), "")

proc thirdPartyInvite*(
  event: RoomMemberEvent
): tuple[ok: bool, invite: Option[ThirdPartyInvite], message: string] =
  roomMemberEventContent(event.content()).thirdPartyInvite()

proc token*(invite: ThirdPartyInvite): tuple[ok: bool, value: string, message: string] =
  let value = invite.signed.jsonField("token")
  if value.kind != JString or value.getStr("").len == 0:
    return (false, "", "missing or invalid `token` field in `third_party_invite.signed`")
  (true, value.getStr(), "")

proc mxid*(invite: ThirdPartyInvite): tuple[ok: bool, value: string, message: string] =
  let value = invite.signed.jsonField("mxid")
  if value.kind != JString or value.getStr("").len == 0:
    return (false, "", "missing or invalid `mxid` field in `third_party_invite.signed`")
  (true, value.getStr(), "")

proc signatures*(invite: ThirdPartyInvite): tuple[ok: bool, value: JsonNode, message: string] =
  let value = invite.signed.jsonField("signatures")
  if value.kind != JObject:
    return (false, newJObject(), "missing or invalid `signatures` field in `third_party_invite.signed`")
  (true, value, "")

proc signedCanonicalJson*(invite: ThirdPartyInvite): tuple[ok: bool, value: string, message: string] =
  let canonical = canonicalSigningString(invite.signed)
  if not canonical.ok:
    return (false, "", canonical.err)
  (true, canonical.value, "")

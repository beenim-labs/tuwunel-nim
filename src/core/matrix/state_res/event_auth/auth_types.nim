const
  RustPath* = "core/matrix/state_res/event_auth/auth_types.rs"
  RustCrate* = "core"

import std/[json, options]

import core/matrix/event/state_key
import core/matrix/pdu
import core/matrix/state_res/events/member
import core/matrix/state_res/json_helpers
import core/matrix/state_res/rules

type
  AuthTypes* = seq[TypeStateKey]
  AuthTypesResult* = tuple[ok: bool, authTypes: AuthTypes, message: string]

proc addUnique(types: var AuthTypes; key: TypeStateKey) =
  if key notin types:
    types.add(key)

proc authTypesForMemberEvent(
  authTypes: var AuthTypes;
  stateKeyValue: Option[string];
  content: JsonNode;
  rules: AuthorizationRules
): tuple[ok: bool, message: string] =
  if stateKeyValue.isNone:
    return (false, "missing `state_key` field for `m.room.member` event")

  authTypes.addUnique(typeStateKey("m.room.member", stateKeyValue.get()))

  let content = roomMemberEventContent(content)
  let membership = content.membership()
  if not membership.ok:
    return (false, membership.message)

  if membership.state in {msJoin, msInvite, msKnock}:
    authTypes.addUnique(typeStateKey("m.room.join_rules", ""))

  if membership.state == msInvite:
    let thirdPartyInvite = content.thirdPartyInvite()
    if not thirdPartyInvite.ok:
      return (false, thirdPartyInvite.message)
    if thirdPartyInvite.invite.isSome:
      let token = thirdPartyInvite.invite.get().token()
      if not token.ok:
        return (false, token.message)
      authTypes.addUnique(typeStateKey("m.room.third_party_invite", token.value))

  if membership.state == msJoin and rules.restrictedJoinRule:
    let authorisedVia = content.joinAuthorisedViaUsersServer()
    if not authorisedVia.ok:
      return (false, authorisedVia.message)
    if authorisedVia.value.isSome:
      authTypes.addUnique(typeStateKey("m.room.member", authorisedVia.value.get()))

  if authTypes.len > MaxAuthEvents:
    return (false, "auth type selection exceeds Matrix auth event limit")
  (true, "")

proc authTypesForEvent*(
  eventType: string;
  sender: string;
  stateKeyValue: Option[string];
  content: JsonNode;
  rules = authorizationRules();
  alwaysCreate = false
): AuthTypesResult =
  var authTypes: AuthTypes = @[]

  if eventType != "m.room.create":
    if not rules.roomCreateEventIdAsRoomId or alwaysCreate:
      authTypes.addUnique(typeStateKey("m.room.create", ""))
    authTypes.addUnique(typeStateKey("m.room.power_levels", ""))
    authTypes.addUnique(typeStateKey("m.room.member", sender))

  if eventType == "m.room.member":
    let memberResult = authTypesForMemberEvent(authTypes, stateKeyValue, content, rules)
    if not memberResult.ok:
      return (false, @[], memberResult.message)

  (true, authTypes, "")

proc authTypesForEvent*(
  event: JsonNode;
  rules = authorizationRules();
  alwaysCreate = false
): AuthTypesResult =
  if event.isNil or event.kind != JObject:
    return (false, @[], "event must be an object")
  var stateKeyValue = none(string)
  if event.hasKey("state_key"):
    stateKeyValue = some(event["state_key"].getStr(""))
  authTypesForEvent(
    event.jsonField("type").getStr(""),
    event.jsonField("sender").getStr(""),
    stateKeyValue,
    event.jsonContent(),
    rules,
    alwaysCreate,
  )

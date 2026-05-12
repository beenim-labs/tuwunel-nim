const
  RustPath* = "core/matrix/state_res/event_auth/room_member.rs"
  RustCrate* = "core"

import std/[json, options, strutils]

import core/crypto/ed25519
import core/matrix/server_signing
import core/matrix/state_res/event_format
import core/matrix/state_res/events/create
import core/matrix/state_res/events/join_rules
import core/matrix/state_res/events/member
import core/matrix/state_res/events/power_levels
import core/matrix/state_res/events/third_party_invite
import core/matrix/state_res/fetch_state
import core/matrix/state_res/rules

type
  RoomMemberAuthResult* = tuple[ok: bool, message: string]

proc allow(): RoomMemberAuthResult =
  (true, "")

proc reject(message: string): RoomMemberAuthResult =
  (false, message)

proc serverName(userId: string): string =
  let index = userId.rfind(":")
  if index < 0 or index == userId.len - 1:
    ""
  else:
    userId[index + 1 .. ^1]

proc validUserId(userId: string): bool =
  userId.startsWith("@") and userId.serverName().len > 0

proc optionPowerLevelsInt(
  event: Option[RoomPowerLevelsEvent];
  field: RoomPowerLevelsIntField;
  rules: AuthorizationRules
): tuple[ok: bool, value: int, message: string] =
  if event.isSome:
    event.get().getAsIntOrDefault(field, rules)
  else:
    (true, field.defaultValue(), "")

proc userPower(
  powerLevels: Option[RoomPowerLevelsEvent];
  userId: string;
  creators: openArray[string];
  rules: AuthorizationRules
): tuple[ok: bool, value: int, message: string] =
  let parsed = powerLevels.userPowerLevel(userId, creators, rules)
  if not parsed.ok:
    return (false, 0, parsed.message)
  (true, parsed.value, "")

proc checkThirdPartyInvite(
  roomMemberEvent: JsonNode;
  targetUser: string;
  fetchState: FetchState
): RoomMemberAuthResult =
  let thirdParty = roomMemberEvent(roomMemberEvent).thirdPartyInvite()
  if not thirdParty.ok:
    return reject(thirdParty.message)
  if thirdParty.invite.isNone:
    return allow()

  let targetMembership = fetchState.userMembership(targetUser)
  if not targetMembership.ok:
    return reject(targetMembership.message)
  if targetMembership.state == msBan:
    return reject("cannot invite user that is banned")

  let invite = thirdParty.invite.get()
  let token = invite.token()
  if not token.ok:
    return reject(token.message)
  let mxid = invite.mxid()
  if not mxid.ok:
    return reject(mxid.message)
  if mxid.value != targetUser:
    return reject("third-party invite mxid does not match target user")

  let roomThirdPartyInvite = fetchState.roomThirdPartyInviteEvent(token.value)
  if roomThirdPartyInvite.isNone:
    return reject("no `m.room.third_party_invite` in room state matches the token")
  if roomMemberEvent.sender() != roomThirdPartyInvite.get().event.sender():
    return reject("sender of `m.room.third_party_invite` does not match sender of `m.room.member`")

  let signatures = invite.signatures()
  if not signatures.ok:
    return reject(signatures.message)
  let publicKeys = roomThirdPartyInvite.get().publicKeys()
  if not publicKeys.ok:
    return reject(publicKeys.message)
  if signatures.value.len == 0 or publicKeys.keys.len == 0:
    return reject("third-party invite signature or public key is missing")

  let canonical = invite.signedCanonicalJson()
  if not canonical.ok:
    return reject(canonical.message)

  for _, entitySignatures in signatures.value:
    if entitySignatures.kind != JObject:
      return reject("unexpected format of `signatures` field in `third_party_invite.signed`")
    for keyId, signatureNode in entitySignatures:
      if not keyId.startsWith("ed25519:") or signatureNode.kind != JString:
        continue
      let signature = decodeUnpaddedBase64(signatureNode.getStr(""))
      if not signature.ok:
        continue
      for encodedPublicKey in publicKeys.keys:
        let publicKey = decodeUnpaddedBase64(encodedPublicKey)
        if publicKey.ok and ed25519.verify(publicKey.data, canonical.value, signature.data):
          return allow()

  reject("no signature on third-party invite matches a public key in `m.room.third_party_invite` event")

proc checkRoomMemberJoin(
  roomMemberEvent: JsonNode;
  targetUser: string;
  rules: AuthorizationRules;
  roomCreateEvent: RoomCreateEvent;
  fetchState: FetchState
): RoomMemberAuthResult =
  let creator = roomCreateEvent.creator(rules)
  if not creator.ok:
    return reject(creator.message)
  let creators = roomCreateEvent.creators(rules)
  if not creators.ok:
    return reject(creators.message)

  let prevEvents = roomMemberEvent.prevEvents()
  if prevEvents.len == 1 and prevEvents[0] == roomCreateEvent.event.eventId() and targetUser == creator.value:
    return allow()

  if roomMemberEvent.sender() != targetUser:
    return reject("sender of join event must match target user")

  let currentMembership = fetchState.userMembership(targetUser)
  if not currentMembership.ok:
    return reject(currentMembership.message)
  if currentMembership.state == msBan:
    return reject("banned user cannot join room")

  let joinRule = fetchState.joinRule()
  if not joinRule.ok:
    return reject(joinRule.message)

  if (joinRule.rule.kind == jrInvite or (rules.knocking and joinRule.rule.kind == jrKnock)) and
      currentMembership.state in {msInvite, msJoin}:
    return allow()

  let restrictedJoin =
    (rules.restrictedJoinRule and joinRule.rule.kind == jrRestricted) or
    (rules.knockRestrictedJoinRule and joinRule.rule.kind == jrKnockRestricted)
  if restrictedJoin:
    if currentMembership.state in {msJoin, msInvite}:
      return allow()

    let authorisedVia = roomMemberEvent(roomMemberEvent).joinAuthorisedViaUsersServer()
    if not authorisedVia.ok:
      return reject(authorisedVia.message)
    if authorisedVia.value.isNone:
      return reject("cannot join restricted room without `join_authorised_via_users_server` field if not invited")

    let authorisedUser = authorisedVia.value.get()
    let authorisedMembership = fetchState.userMembership(authorisedUser)
    if not authorisedMembership.ok:
      return reject(authorisedMembership.message)
    if authorisedMembership.state != msJoin:
      return reject("`join_authorised_via_users_server` is not joined")

    let powerLevels = fetchState.roomPowerLevelsEvent()
    let authorisedPower = powerLevels.userPower(authorisedUser, creators.values, rules)
    if not authorisedPower.ok:
      return reject(authorisedPower.message)
    let invitePower = powerLevels.optionPowerLevelsInt(plInvite, rules)
    if not invitePower.ok:
      return reject(invitePower.message)
    if authorisedPower.value < invitePower.value:
      return reject("`join_authorised_via_users_server` does not have enough power")
    return allow()

  if joinRule.rule.kind != jrPublic:
    return reject("cannot join a room that is not `public`")

  allow()

proc checkRoomMemberInvite(
  roomMemberEvent: JsonNode;
  targetUser: string;
  rules: AuthorizationRules;
  roomCreateEvent: RoomCreateEvent;
  fetchState: FetchState
): RoomMemberAuthResult =
  let thirdParty = roomMemberEvent(roomMemberEvent).thirdPartyInvite()
  if not thirdParty.ok:
    return reject(thirdParty.message)
  if thirdParty.invite.isSome:
    return checkThirdPartyInvite(roomMemberEvent, targetUser, fetchState)

  let senderMembership = fetchState.userMembership(roomMemberEvent.sender())
  if not senderMembership.ok:
    return reject(senderMembership.message)
  if senderMembership.state != msJoin:
    return reject("cannot invite user if sender is not joined")

  let targetMembership = fetchState.userMembership(targetUser)
  if not targetMembership.ok:
    return reject(targetMembership.message)
  if targetMembership.state in {msJoin, msBan}:
    return reject("cannot invite user that is joined or banned")

  let creators = roomCreateEvent.creators(rules)
  if not creators.ok:
    return reject(creators.message)
  let powerLevels = fetchState.roomPowerLevelsEvent()
  let senderPower = powerLevels.userPower(roomMemberEvent.sender(), creators.values, rules)
  if not senderPower.ok:
    return reject(senderPower.message)
  let invitePower = powerLevels.optionPowerLevelsInt(plInvite, rules)
  if not invitePower.ok:
    return reject(invitePower.message)
  if senderPower.value < invitePower.value:
    return reject("sender does not have enough power to invite")

  allow()

proc checkRoomMemberLeave(
  roomMemberEvent: JsonNode;
  targetUser: string;
  rules: AuthorizationRules;
  roomCreateEvent: RoomCreateEvent;
  fetchState: FetchState
): RoomMemberAuthResult =
  let senderMembership = fetchState.userMembership(roomMemberEvent.sender())
  if not senderMembership.ok:
    return reject(senderMembership.message)

  if roomMemberEvent.sender() == targetUser:
    if senderMembership.state in {msJoin, msInvite} or (rules.knocking and senderMembership.state == msKnock):
      return allow()
    return reject("cannot leave if not joined, invited or knocked")

  if senderMembership.state != msJoin:
    return reject("cannot kick if sender is not joined")

  let creators = roomCreateEvent.creators(rules)
  if not creators.ok:
    return reject(creators.message)
  let powerLevels = fetchState.roomPowerLevelsEvent()
  let targetMembership = fetchState.userMembership(targetUser)
  if not targetMembership.ok:
    return reject(targetMembership.message)
  let senderPower = powerLevels.userPower(roomMemberEvent.sender(), creators.values, rules)
  if not senderPower.ok:
    return reject(senderPower.message)

  let banPower = powerLevels.optionPowerLevelsInt(plBan, rules)
  if not banPower.ok:
    return reject(banPower.message)
  if targetMembership.state == msBan and senderPower.value < banPower.value:
    return reject("sender does not have enough power to unban")

  let kickPower = powerLevels.optionPowerLevelsInt(plKick, rules)
  if not kickPower.ok:
    return reject(kickPower.message)
  let targetPower = powerLevels.userPower(targetUser, creators.values, rules)
  if not targetPower.ok:
    return reject(targetPower.message)

  if senderPower.value >= kickPower.value and targetPower.value < senderPower.value:
    allow()
  else:
    reject("sender does not have enough power to kick target user")

proc checkRoomMemberBan(
  roomMemberEvent: JsonNode;
  targetUser: string;
  rules: AuthorizationRules;
  roomCreateEvent: RoomCreateEvent;
  fetchState: FetchState
): RoomMemberAuthResult =
  let senderMembership = fetchState.userMembership(roomMemberEvent.sender())
  if not senderMembership.ok:
    return reject(senderMembership.message)
  if senderMembership.state != msJoin:
    return reject("cannot ban if sender is not joined")

  let creators = roomCreateEvent.creators(rules)
  if not creators.ok:
    return reject(creators.message)
  let powerLevels = fetchState.roomPowerLevelsEvent()
  let senderPower = powerLevels.userPower(roomMemberEvent.sender(), creators.values, rules)
  if not senderPower.ok:
    return reject(senderPower.message)
  let banPower = powerLevels.optionPowerLevelsInt(plBan, rules)
  if not banPower.ok:
    return reject(banPower.message)
  let targetPower = powerLevels.userPower(targetUser, creators.values, rules)
  if not targetPower.ok:
    return reject(targetPower.message)

  if senderPower.value >= banPower.value and targetPower.value < senderPower.value:
    allow()
  else:
    reject("sender does not have enough power to ban target user")

proc checkRoomMemberKnock(
  roomMemberEvent: JsonNode;
  targetUser: string;
  rules: AuthorizationRules;
  fetchState: FetchState
): RoomMemberAuthResult =
  let joinRule = fetchState.joinRule()
  if not joinRule.ok:
    return reject(joinRule.message)
  let supportsKnock =
    joinRule.rule.kind == jrKnock or
    (rules.knockRestrictedJoinRule and joinRule.rule.kind == jrKnockRestricted)
  if not supportsKnock:
    return reject("join rule is not set to knock or knock_restricted, knocking is not allowed")

  if roomMemberEvent.sender() != targetUser:
    return reject("cannot make another user knock, sender does not match target user")

  let senderMembership = fetchState.userMembership(roomMemberEvent.sender())
  if not senderMembership.ok:
    return reject(senderMembership.message)
  if senderMembership.state notin {msBan, msInvite, msJoin}:
    allow()
  else:
    reject("cannot knock if user is banned, invited or joined")

proc checkRoomMember*(
  roomMemberEvent: JsonNode;
  rules: AuthorizationRules;
  roomCreateEvent: RoomCreateEvent;
  fetchState: FetchState
): RoomMemberAuthResult =
  let stateKey = roomMemberEvent.stateKey()
  if stateKey.isNone:
    return reject("missing `state_key` field in `m.room.member` event")
  let targetUser = stateKey.get()
  if not validUserId(targetUser):
    return reject("invalid `state_key` field in `m.room.member` event")

  let federate = roomCreateEvent.federate()
  if not federate.ok:
    return reject(federate.message)
  if not federate.value and targetUser.serverName() != roomCreateEvent.sender().serverName():
    return reject("MSC4361: room is not federated and target user domain does not match `m.room.create` event's sender domain")

  let targetMembership = roomMemberEvent(roomMemberEvent).membership()
  if not targetMembership.ok:
    return reject(targetMembership.message)

  case targetMembership.state
  of msJoin:
    checkRoomMemberJoin(roomMemberEvent, targetUser, rules, roomCreateEvent, fetchState)
  of msInvite:
    checkRoomMemberInvite(roomMemberEvent, targetUser, rules, roomCreateEvent, fetchState)
  of msLeave:
    checkRoomMemberLeave(roomMemberEvent, targetUser, rules, roomCreateEvent, fetchState)
  of msBan:
    checkRoomMemberBan(roomMemberEvent, targetUser, rules, roomCreateEvent, fetchState)
  of msKnock:
    if rules.knocking:
      checkRoomMemberKnock(roomMemberEvent, targetUser, rules, fetchState)
    else:
      reject("unknown membership")
  of msCustom:
    reject("unknown membership")

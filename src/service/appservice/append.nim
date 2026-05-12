const
  RustPath* = "service/appservice/append.rs"
  RustCrate* = "service"

import service/appservice/[namespace_regex, registration_info]

type
  AppservicePdu* = object
    pduId*: string
    eventId*: string
    roomId*: string
    sender*: string
    kind*: string
    stateKey*: string
    aliases*: seq[string]
    appserviceInRoom*: bool

proc shouldAppendTo*(appservice: RegistrationInfo; pdu: AppservicePdu): bool =
  if pdu.appserviceInRoom:
    return true

  if appservice.isUserMatch(pdu.sender):
    return true

  if pdu.kind == "m.room.member" and pdu.stateKey.len > 0 and appservice.isUserMatch(pdu.stateKey):
    return true

  for alias in pdu.aliases:
    if appservice.aliases.isMatch(alias):
      return true

  if appservice.rooms.isMatch(pdu.roomId):
    return true

  false

proc appendPduTo*(appservice: RegistrationInfo; pdu: AppservicePdu): tuple[queued: bool, registrationId: string, pduId: string] =
  if appservice.shouldAppendTo(pdu):
    return (true, appservice.registration.id, pdu.pduId)
  (false, appservice.registration.id, "")

proc appendPdu*(registrations: openArray[RegistrationInfo]; pdu: AppservicePdu): seq[tuple[registrationId: string, pduId: string]] =
  result = @[]
  for appservice in registrations:
    let queued = appendPduTo(appservice, pdu)
    if queued.queued:
      result.add((queued.registrationId, queued.pduId))

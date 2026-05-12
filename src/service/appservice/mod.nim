const
  RustPath* = "service/appservice/mod.rs"
  RustCrate* = "service"

import std/[algorithm, tables]

import service/appservice/[append, namespace_regex, registration_info, request]

export append, namespace_regex, registration_info, request

type
  AppserviceResult* = tuple[ok: bool, message: string]

  AppserviceService* = object
    serverName*: string
    registrationInfo*: OrderedTable[string, RegistrationInfo]
    dbRegistrations*: Table[string, AppserviceRegistration]
    knownUsers*: Table[string, bool]
    cleanupRequests*: seq[string]

proc initAppserviceService*(serverName: string): AppserviceService =
  AppserviceService(
    serverName: serverName,
    registrationInfo: initOrderedTable[string, RegistrationInfo](),
    dbRegistrations: initTable[string, AppserviceRegistration](),
    knownUsers: initTable[string, bool](),
    cleanupRequests: @[],
  )

proc loadAppservice*(service: var AppserviceService; registration: AppserviceRegistration): AppserviceResult =
  let info = newRegistrationInfo(registration, service.serverName)
  let id = info.registration.id
  if id.len == 0:
    return (false, "missing appservice id")

  for loaded in service.registrationInfo.values:
    if loaded.registration.id == id:
      return (false, "Duplicate id: " & id)
    if loaded.registration.asToken == info.registration.asToken:
      return (false, "Duplicate as_token: " & loaded.registration.id & " " & id)

  service.knownUsers[info.sender] = true
  service.registrationInfo[id] = info
  (true, "")

proc registerAppservice*(service: var AppserviceService; registration: AppserviceRegistration): AppserviceResult =
  let loaded = service.loadAppservice(registration)
  if not loaded.ok:
    return loaded
  service.dbRegistrations[registration.id] = registration
  loaded

proc unregisterAppservice*(service: var AppserviceService; appserviceId: string): AppserviceResult =
  if appserviceId notin service.registrationInfo:
    return (false, "Appservice not found")
  if appserviceId notin service.dbRegistrations:
    return (false, "Cannot unregister config appservice")

  service.registrationInfo.del(appserviceId)
  service.dbRegistrations.del(appserviceId)
  service.cleanupRequests.add(appserviceId)
  (true, "")

proc getRegistration*(service: AppserviceService; id: string): tuple[ok: bool, registration: AppserviceRegistration] =
  if id notin service.registrationInfo:
    return (false, AppserviceRegistration())
  (true, service.registrationInfo[id].registration)

proc findFromAccessToken*(service: AppserviceService; token: string): tuple[ok: bool, info: RegistrationInfo] =
  for info in service.registrationInfo.values:
    if info.registration.asToken == token:
      return (true, info)
  (false, RegistrationInfo())

proc isExclusiveUserId*(service: AppserviceService; userId: string): bool =
  for info in service.registrationInfo.values:
    if info.isExclusiveUserMatch(userId):
      return true
  false

proc isExclusiveAlias*(service: AppserviceService; alias: string): bool =
  for info in service.registrationInfo.values:
    if info.aliases.isExclusiveMatch(alias):
      return true
  false

proc isExclusiveRoomId*(service: AppserviceService; roomId: string): bool =
  for info in service.registrationInfo.values:
    if info.rooms.isExclusiveMatch(roomId):
      return true
  false

proc iterIds*(service: AppserviceService): seq[string] =
  result = @[]
  for id in service.registrationInfo.keys:
    result.add(id)
  result.sort(system.cmp[string])

proc iterDbIds*(service: AppserviceService): seq[string] =
  result = @[]
  for id in service.dbRegistrations.keys:
    result.add(id)
  result.sort(system.cmp[string])

proc getDbRegistration*(service: AppserviceService; id: string): tuple[ok: bool, registration: AppserviceRegistration] =
  if id notin service.dbRegistrations:
    return (false, AppserviceRegistration())
  (true, service.dbRegistrations[id])

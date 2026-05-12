const
  RustPath* = "service/sending/mod.rs"
  RustCrate* = "service"

import std/[hashes, tables]

import service/sending/[data, dest, sender]

export data, dest, sender

type
  Msg* = object
    dest*: Destination
    event*: SendingEvent
    queueId*: string

  CleanupResult* = tuple[cleaned: bool, deleted: int, warning: bool]

  SendingService* = object
    db*: SendingData
    localServerName*: string
    senderWorkers*: int
    dispatches*: seq[Msg]
    roomServers*: Table[string, seq[string]]

proc numSenders*(requested, runtimeWorkers, availableParallelism: int): int =
  let maxSenders = max(1, min(runtimeWorkers, availableParallelism))
  clamp(requested, 1, maxSenders)

proc initSendingService*(
  localServerName = "example.test";
  senderWorkers = 1;
): SendingService =
  SendingService(
    db: initSendingData(),
    localServerName: localServerName,
    senderWorkers: max(1, senderWorkers),
    dispatches: @[],
    roomServers: initTable[string, seq[string]](),
  )

proc shardId*(service: SendingService; dest: Destination): int =
  if service.senderWorkers <= 1:
    return 0
  abs(hash(dest.destinationId())) mod service.senderWorkers

proc dispatch*(service: var SendingService; msg: Msg): bool =
  service.dispatches.add(msg)
  true

proc queueAndDispatch(service: var SendingService; dest: Destination; event: SendingEvent): string =
  let keys = service.db.queueRequests([(event: event, dest: dest)])
  result = keys[0]
  discard service.dispatch(Msg(dest: dest, event: event, queueId: result))

proc sendPduPush*(service: var SendingService; pduId, userId, pushkey: string): string =
  service.queueAndDispatch(pushDestination(userId, pushkey), pduEvent(pduId))

proc sendPduAppservice*(service: var SendingService; appserviceId, pduId: string): string =
  service.queueAndDispatch(appserviceDestination(appserviceId), pduEvent(pduId))

proc sendPduServers*(service: var SendingService; servers: openArray[string]; pduId: string): seq[string] =
  result = @[]
  for serverName in servers:
    if serverName == service.localServerName:
      continue
    result.add(service.queueAndDispatch(federationDestination(serverName), pduEvent(pduId)))

proc setRoomServers*(service: var SendingService; roomId: string; servers: openArray[string]) =
  service.roomServers[roomId] = @servers

proc sendPduRoom*(service: var SendingService; roomId, pduId: string): seq[string] =
  service.sendPduServers(service.roomServers.getOrDefault(roomId, @[]), pduId)

proc sendEduServer*(service: var SendingService; serverName, serialized: string): string =
  if serverName == service.localServerName:
    return ""
  service.queueAndDispatch(federationDestination(serverName), eduEvent(serialized))

proc sendEduServers*(service: var SendingService; servers: openArray[string]; serialized: string): seq[string] =
  result = @[]
  for serverName in servers:
    let key = service.sendEduServer(serverName, serialized)
    if key.len > 0:
      result.add(key)

proc sendEduRoom*(service: var SendingService; roomId, serialized: string): seq[string] =
  service.sendEduServers(service.roomServers.getOrDefault(roomId, @[]), serialized)

proc sendEduAppservice*(service: var SendingService; appserviceId, serialized: string): string =
  service.queueAndDispatch(appserviceDestination(appserviceId), eduEvent(serialized))

proc flushServers*(service: var SendingService; servers: openArray[string]): int =
  result = 0
  for serverName in servers:
    if serverName == service.localServerName:
      continue
    discard service.dispatch(Msg(
      dest: federationDestination(serverName),
      event: flushEvent(),
      queueId: "",
    ))
    inc result

proc flushRoom*(service: var SendingService; roomId: string): int =
  service.flushServers(service.roomServers.getOrDefault(roomId, @[]))

proc cleanupEvents*(
  service: var SendingService;
  appserviceId = "";
  userId = "";
  pushkey = "";
): CleanupResult =
  if appserviceId.len == 0 and userId.len > 0 and pushkey.len > 0:
    let deleted = service.db.deleteAllRequestsFor(pushDestination(userId, pushkey))
    return (true, deleted, false)
  if appserviceId.len > 0 and userId.len == 0 and pushkey.len == 0:
    let deleted = service.db.deleteAllRequestsFor(appserviceDestination(appserviceId))
    return (true, deleted, false)
  (false, 0, true)

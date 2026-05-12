const
  RustPath* = "service/rooms/typing/mod.rs"
  RustCrate* = "service"

import std/[algorithm, json, sets, tables]

type
  TypingResult* = tuple[ok: bool, errcode: string, message: string]

  TypingService* = object
    typing*: Table[string, Table[string, uint64]]
    lastTypingUpdate*: Table[string, uint64]
    ignoredUsers*: Table[string, HashSet[string]]
    sentFederationEdus*: seq[JsonNode]
    sentAppserviceEdus*: seq[JsonNode]
    nextCount*: uint64
    allowOutgoingTyping*: bool

proc initTypingService*(allowOutgoingTyping = true): TypingService =
  TypingService(
    typing: initTable[string, Table[string, uint64]](),
    lastTypingUpdate: initTable[string, uint64](),
    ignoredUsers: initTable[string, HashSet[string]](),
    sentFederationEdus: @[],
    sentAppserviceEdus: @[],
    nextCount: 0'u64,
    allowOutgoingTyping: allowOutgoingTyping,
  )

proc okResult(): TypingResult =
  (true, "", "")

proc nextUpdate(service: var TypingService; roomId: string): uint64 =
  inc service.nextCount
  service.lastTypingUpdate[roomId] = service.nextCount
  service.nextCount

proc sortedUsers(users: Table[string, uint64]): seq[string] =
  result = @[]
  for userId in users.keys:
    result.add(userId)
  result.sort(system.cmp[string])

proc typingContent*(service: TypingService; roomId: string): JsonNode =
  let users =
    if roomId in service.typing:
      sortedUsers(service.typing[roomId])
    else:
      @[]
  result = %*{
    "type": "m.typing",
    "content": {
      "user_ids": users,
    },
  }

proc appserviceSend(service: var TypingService; roomId: string) =
  var payload = service.typingContent(roomId)
  payload["room_id"] = %roomId
  service.sentAppserviceEdus.add(payload)

proc federationSend(service: var TypingService; roomId, userId: string; typing: bool) =
  if not service.allowOutgoingTyping:
    return
  service.sentFederationEdus.add(%*{
    "edu_type": "m.typing",
    "content": {
      "room_id": roomId,
      "user_id": userId,
      "typing": typing,
    },
  })

proc typingAdd*(
  service: var TypingService;
  userId, roomId: string;
  timeout: uint64;
  localUser = true;
): TypingResult =
  var room = service.typing.getOrDefault(roomId, initTable[string, uint64]())
  room[userId] = timeout
  service.typing[roomId] = room
  discard service.nextUpdate(roomId)
  service.appserviceSend(roomId)
  if localUser:
    service.federationSend(roomId, userId, true)
  okResult()

proc typingRemove*(
  service: var TypingService;
  userId, roomId: string;
  localUser = true;
): TypingResult =
  var room = service.typing.getOrDefault(roomId, initTable[string, uint64]())
  room.del(userId)
  service.typing[roomId] = room
  discard service.nextUpdate(roomId)
  service.appserviceSend(roomId)
  if localUser:
    service.federationSend(roomId, userId, false)
  okResult()

proc typingsMaintain*(service: var TypingService; roomId: string; nowMs: uint64): int =
  result = 0
  if roomId notin service.typing:
    return
  var room = service.typing[roomId]
  var removable: seq[string] = @[]
  for userId, timeout in room:
    if timeout < nowMs:
      removable.add(userId)
  if removable.len == 0:
    return
  removable.sort(system.cmp[string])
  for userId in removable:
    room.del(userId)
    service.federationSend(roomId, userId, false)
    inc result
  service.typing[roomId] = room
  discard service.nextUpdate(roomId)
  service.appserviceSend(roomId)

proc lastTypingUpdateCount*(service: var TypingService; roomId: string; nowMs = 0'u64): uint64 =
  if nowMs > 0:
    discard service.typingsMaintain(roomId, nowMs)
  service.lastTypingUpdate.getOrDefault(roomId, 0'u64)

proc ignoreUser*(service: var TypingService; senderUser, ignoredUser: string) =
  var ignored = service.ignoredUsers.getOrDefault(senderUser, initHashSet[string]())
  ignored.incl(ignoredUser)
  service.ignoredUsers[senderUser] = ignored

proc userIsIgnored(service: TypingService; typingUserId, senderUser: string): bool =
  senderUser in service.ignoredUsers and typingUserId in service.ignoredUsers[senderUser]

proc typingUsersForUser*(
  service: var TypingService;
  roomId, senderUser: string;
  nowMs = 0'u64;
): seq[string] =
  result = @[]
  if nowMs > 0:
    discard service.typingsMaintain(roomId, nowMs)
  if roomId notin service.typing:
    return
  for userId in sortedUsers(service.typing[roomId]):
    if not service.userIsIgnored(userId, senderUser):
      result.add(userId)

proc waitForUpdateObserved*(service: TypingService; roomId: string; since: uint64): bool =
  service.lastTypingUpdate.getOrDefault(roomId, 0'u64) > since

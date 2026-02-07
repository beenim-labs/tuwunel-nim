import std/[json, options, strutils, tables, times]
import api/router/response

const
  RustPath* = "api/router/state.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  UserRecord* = object
    userId*: string
    password*: string
    displayName*: string
    avatarUrl*: string
    presence*: string
    deactivated*: bool

  SessionRecord* = object
    token*: string
    userId*: string
    deviceId*: string
    deviceDisplayName*: string

  RoomEventRecord* = object
    eventId*: string
    roomId*: string
    sender*: string
    eventType*: string
    stateKey*: Option[string]
    content*: JsonNode
    originServerTs*: int64
    streamPos*: int

  RoomRecord* = object
    roomId*: string
    creator*: string
    name*: string
    topic*: string
    visibility*: string
    canonicalAlias*: string
    members*: Table[string, string]
    timeline*: seq[string]
    stateEvents*: Table[string, string]

  ApiRouterState* = ref object
    totalRequests*: int
    okResponses*: int
    deniedResponses*: int
    statusCounts*: Table[int, int]
    lastRoute*: string
    lastStatus*: int
    users*: Table[string, UserRecord]
    sessions*: Table[string, SessionRecord]
    userCounter*: int
    sessionCounter*: int
    rooms*: Table[string, RoomRecord]
    roomAliases*: Table[string, string]
    events*: Table[string, RoomEventRecord]
    stream*: seq[string]
    roomCounter*: int
    eventCounter*: int
    streamCounter*: int

proc initApiRouterState*(): ApiRouterState =
  new(result)
  result.totalRequests = 0
  result.okResponses = 0
  result.deniedResponses = 0
  result.statusCounts = initTable[int, int]()
  result.lastRoute = ""
  result.lastStatus = 0
  result.users = initTable[string, UserRecord]()
  result.sessions = initTable[string, SessionRecord]()
  result.userCounter = 0
  result.sessionCounter = 0
  result.rooms = initTable[string, RoomRecord]()
  result.roomAliases = initTable[string, string]()
  result.events = initTable[string, RoomEventRecord]()
  result.stream = @[]
  result.roomCounter = 0
  result.eventCounter = 0
  result.streamCounter = 0

proc record*(state: ApiRouterState; resp: ApiResponse) =
  inc state.totalRequests
  if resp.ok:
    inc state.okResponses
  else:
    inc state.deniedResponses
  state.statusCounts[resp.status] = state.statusCounts.getOrDefault(resp.status, 0) + 1
  state.lastRoute = resp.routeName
  state.lastStatus = resp.status

proc statusHits*(state: ApiRouterState; status: int): int =
  state.statusCounts.getOrDefault(status, 0)

proc nextUserId*(state: ApiRouterState): string =
  inc state.userCounter
  "@user" & $state.userCounter & ":tuwunel-nim"

proc normalizeUserId*(raw: string): string =
  let value = raw.strip()
  if value.len == 0:
    return ""
  if value.startsWith("@"):
    return value
  "@" & value & ":tuwunel-nim"

proc normalizeRoomAlias*(raw: string): string =
  let value = raw.strip()
  if value.len == 0:
    return ""
  var alias = value
  if not alias.startsWith("#"):
    alias = "#" & alias
  if ':' notin alias:
    alias.add(":tuwunel-nim")
  alias

proc parseSinceToken*(token: string): int =
  let trimmed = token.strip()
  if trimmed.len == 0:
    return 0
  if trimmed.startsWith("s") and trimmed.len > 1:
    try:
      return parseInt(trimmed[1 .. ^1])
    except ValueError:
      return 0
  try:
    parseInt(trimmed)
  except ValueError:
    0

proc encodeSinceToken*(position: int): string =
  "s" & $max(position, 0)

proc currentStreamPosition*(state: ApiRouterState): int =
  state.streamCounter

proc userExists*(state: ApiRouterState; userId: string): bool =
  normalizeUserId(userId) in state.users

proc createUser*(state: ApiRouterState; userId, password, displayName: string): bool =
  let normalized = normalizeUserId(userId)
  if normalized.len == 0 or normalized in state.users:
    return false
  state.users[normalized] = UserRecord(
    userId: normalized,
    password: password,
    displayName: displayName,
    avatarUrl: "",
    presence: "offline",
    deactivated: false,
  )
  true

proc verifyPassword*(state: ApiRouterState; userId, password: string): bool =
  let normalized = normalizeUserId(userId)
  if normalized notin state.users:
    return false
  let user = state.users[normalized]
  (not user.deactivated) and user.password == password

proc issueSession*(
    state: ApiRouterState; userId: string; deviceId = ""; deviceDisplayName = ""): SessionRecord =
  inc state.sessionCounter
  let normalized = normalizeUserId(userId)
  let token = "nimtok-" & $state.sessionCounter
  let device =
    if deviceId.strip().len > 0: deviceId.strip()
    else: "NIM-" & $state.sessionCounter
  let display =
    if deviceDisplayName.strip().len > 0: deviceDisplayName.strip()
    else: device
  result = SessionRecord(
    token: token,
    userId: normalized,
    deviceId: device,
    deviceDisplayName: display,
  )
  state.sessions[token] = result

proc resolveSession*(state: ApiRouterState; token: string): tuple[ok: bool, session: SessionRecord] =
  if token in state.sessions:
    return (true, state.sessions[token])
  (false, SessionRecord())

proc revokeSession*(state: ApiRouterState; token: string): bool =
  if token notin state.sessions:
    return false
  state.sessions.del(token)
  true

proc revokeAllSessions*(state: ApiRouterState; userId: string): int =
  let normalized = normalizeUserId(userId)
  var removed: seq[string] = @[]
  for token, sess in state.sessions.pairs:
    if sess.userId == normalized:
      removed.add(token)
  for token in removed:
    state.sessions.del(token)
  removed.len

proc setPassword*(state: ApiRouterState; userId, password: string): bool =
  let normalized = normalizeUserId(userId)
  if normalized notin state.users:
    return false
  var user = state.users[normalized]
  user.password = password
  state.users[normalized] = user
  true

proc setDisplayName*(state: ApiRouterState; userId, displayName: string): bool =
  let normalized = normalizeUserId(userId)
  if normalized notin state.users:
    return false
  var user = state.users[normalized]
  user.displayName = displayName
  state.users[normalized] = user
  true

proc setAvatarUrl*(state: ApiRouterState; userId, avatarUrl: string): bool =
  let normalized = normalizeUserId(userId)
  if normalized notin state.users:
    return false
  var user = state.users[normalized]
  user.avatarUrl = avatarUrl
  state.users[normalized] = user
  true

proc setPresence*(state: ApiRouterState; userId, presence: string): bool =
  let normalized = normalizeUserId(userId)
  if normalized notin state.users:
    return false
  var user = state.users[normalized]
  user.presence = presence
  state.users[normalized] = user
  true

proc deactivateUser*(state: ApiRouterState; userId: string): bool =
  let normalized = normalizeUserId(userId)
  if normalized notin state.users:
    return false
  var user = state.users[normalized]
  user.deactivated = true
  state.users[normalized] = user
  discard state.revokeAllSessions(normalized)
  true

proc getUser*(state: ApiRouterState; userId: string): tuple[ok: bool, user: UserRecord] =
  let normalized = normalizeUserId(userId)
  if normalized in state.users:
    return (true, state.users[normalized])
  (false, UserRecord())

proc sessionForDevice*(state: ApiRouterState; userId, deviceId: string): tuple[ok: bool, session: SessionRecord] =
  let normalized = normalizeUserId(userId)
  for _, session in state.sessions.pairs:
    if session.userId == normalized and session.deviceId == deviceId:
      return (true, session)
  (false, SessionRecord())

proc listSessions*(state: ApiRouterState; userId: string): seq[SessionRecord] =
  let normalized = normalizeUserId(userId)
  result = @[]
  for _, session in state.sessions.pairs:
    if session.userId == normalized:
      result.add(session)

proc updateDeviceDisplayName*(state: ApiRouterState; userId, deviceId, displayName: string): bool =
  let normalized = normalizeUserId(userId)
  var targetToken = ""
  var targetSession = SessionRecord()
  for token, session in state.sessions.pairs:
    if session.userId != normalized or session.deviceId != deviceId:
      continue
    targetToken = token
    targetSession = session
    break
  if targetToken.len == 0:
    return false
  targetSession.deviceDisplayName = displayName
  state.sessions[targetToken] = targetSession
  true

proc revokeDevice*(state: ApiRouterState; userId, deviceId: string): bool =
  let normalized = normalizeUserId(userId)
  var targetToken = ""
  for token, session in state.sessions.pairs:
    if session.userId == normalized and session.deviceId == deviceId:
      targetToken = token
      break
  if targetToken.len == 0:
    return false
  state.sessions.del(targetToken)
  true

proc revokeDevices*(state: ApiRouterState; userId: string; deviceIds: openArray[string]): int =
  result = 0
  for deviceId in deviceIds:
    if state.revokeDevice(userId, deviceId):
      inc result

proc localUserCount*(state: ApiRouterState): int =
  state.users.len

proc nextRoomId*(state: ApiRouterState): string =
  inc state.roomCounter
  "!nim-room-" & $state.roomCounter & ":tuwunel-nim"

proc normalizeRoomIdOrAlias*(raw: string): string =
  raw.strip()

proc resolveRoom*(state: ApiRouterState; roomIdOrAlias: string): tuple[ok: bool, roomId: string] =
  let normalized = normalizeRoomIdOrAlias(roomIdOrAlias)
  if normalized.len == 0:
    return (false, "")
  if normalized in state.rooms:
    return (true, normalized)
  let alias = normalizeRoomAlias(normalized)
  if alias.len > 0 and alias in state.roomAliases:
    return (true, state.roomAliases[alias])
  (false, "")

proc stateEventKey(eventType, stateKey: string): string =
  eventType & "\x1F" & stateKey

proc updateRoomStateFromEvent(room: var RoomRecord; event: RoomEventRecord) =
  if event.stateKey.isNone:
    return
  let key = event.stateKey.get()
  room.stateEvents[stateEventKey(event.eventType, key)] = event.eventId
  if event.eventType == "m.room.name" and event.content.kind == JObject and "name" in event.content:
    room.name = event.content["name"].getStr()
  elif event.eventType == "m.room.topic" and event.content.kind == JObject and "topic" in event.content:
    room.topic = event.content["topic"].getStr()
  elif event.eventType == "m.room.canonical_alias" and event.content.kind == JObject and "alias" in event.content:
    let alias = normalizeRoomAlias(event.content["alias"].getStr())
    if alias.len > 0:
      room.canonicalAlias = alias
      state.roomAliases[alias] = room.roomId
  elif event.eventType == "m.room.member":
    let membership =
      if event.content.kind == JObject and "membership" in event.content:
        event.content["membership"].getStr().strip().toLowerAscii()
      else:
        ""
    if membership.len > 0:
      room.members[normalizeUserId(key)] = membership

proc putEvent(
    state: ApiRouterState; roomId, sender, eventType: string; content: JsonNode; stateKey = none(string)): RoomEventRecord =
  inc state.eventCounter
  inc state.streamCounter
  let eventId = "$nim-" & $state.eventCounter & ":tuwunel-nim"
  result = RoomEventRecord(
    eventId: eventId,
    roomId: roomId,
    sender: normalizeUserId(sender),
    eventType: eventType,
    stateKey: stateKey,
    content: content,
    originServerTs: int64(epochTime() * 1000),
    streamPos: state.streamCounter,
  )
  state.events[eventId] = result
  state.stream.add(eventId)

  if roomId in state.rooms:
    var room = state.rooms[roomId]
    room.timeline.add(eventId)
    updateRoomStateFromEvent(room, result)
    state.rooms[roomId] = room

proc userCanAccessRoom(state: ApiRouterState; userId, roomId: string): bool =
  let normalized = normalizeUserId(userId)
  if roomId notin state.rooms:
    return false
  let room = state.rooms[roomId]
  room.members.getOrDefault(normalized) == "join"

proc createRoom*(
    state: ApiRouterState; creator: string; name = ""; topic = ""; visibility = "private";
    roomAlias = ""): tuple[ok: bool, roomId: string, errcode: string] =
  let creatorId = normalizeUserId(creator)
  if creatorId.len == 0 or creatorId notin state.users:
    return (false, "", "M_FORBIDDEN")

  let alias = normalizeRoomAlias(roomAlias)
  if alias.len > 0 and alias in state.roomAliases:
    return (false, "", "M_ROOM_IN_USE")

  let roomId = state.nextRoomId()
  var room = RoomRecord(
    roomId: roomId,
    creator: creatorId,
    name: name,
    topic: topic,
    visibility: visibility.strip().toLowerAscii(),
    canonicalAlias: alias,
    members: initTable[string, string](),
    timeline: @[],
    stateEvents: initTable[string, string](),
  )
  room.members[creatorId] = "join"
  state.rooms[roomId] = room
  if alias.len > 0:
    state.roomAliases[alias] = roomId

  discard state.putEvent(
    roomId = roomId,
    sender = creatorId,
    eventType = "m.room.member",
    stateKey = some(creatorId),
    content = %*{"membership": "join"},
  )
  if name.len > 0:
    discard state.putEvent(
      roomId = roomId,
      sender = creatorId,
      eventType = "m.room.name",
      stateKey = some(""),
      content = %*{"name": name},
    )
  if topic.len > 0:
    discard state.putEvent(
      roomId = roomId,
      sender = creatorId,
      eventType = "m.room.topic",
      stateKey = some(""),
      content = %*{"topic": topic},
    )
  if alias.len > 0:
    discard state.putEvent(
      roomId = roomId,
      sender = creatorId,
      eventType = "m.room.canonical_alias",
      stateKey = some(""),
      content = %*{"alias": alias},
    )

  (true, roomId, "")

proc getRoom*(state: ApiRouterState; roomId: string): tuple[ok: bool, room: RoomRecord] =
  if roomId in state.rooms:
    return (true, state.rooms[roomId])
  (false, RoomRecord())

proc createEvent*(
    state: ApiRouterState; userId, roomId, eventType: string; content: JsonNode;
    stateKey = none(string)): tuple[ok: bool, event: RoomEventRecord, errcode: string] =
  let normalizedUser = normalizeUserId(userId)
  if normalizedUser notin state.users:
    return (false, RoomEventRecord(), "M_FORBIDDEN")
  if roomId notin state.rooms:
    return (false, RoomEventRecord(), "M_NOT_FOUND")
  if not state.userCanAccessRoom(normalizedUser, roomId):
    return (false, RoomEventRecord(), "M_FORBIDDEN")
  let event = state.putEvent(roomId, normalizedUser, eventType, content, stateKey)
  (true, event, "")

proc joinRoom*(state: ApiRouterState; userId, roomIdOrAlias: string): tuple[ok: bool, roomId: string, errcode: string] =
  let normalizedUser = normalizeUserId(userId)
  if normalizedUser notin state.users:
    return (false, "", "M_FORBIDDEN")
  let resolved = state.resolveRoom(roomIdOrAlias)
  if not resolved.ok:
    return (false, "", "M_NOT_FOUND")
  var room = state.rooms[resolved.roomId]
  room.members[normalizedUser] = "join"
  state.rooms[resolved.roomId] = room
  discard state.putEvent(
    roomId = resolved.roomId,
    sender = normalizedUser,
    eventType = "m.room.member",
    stateKey = some(normalizedUser),
    content = %*{"membership": "join"},
  )
  (true, resolved.roomId, "")

proc leaveRoom*(state: ApiRouterState; userId, roomIdOrAlias: string): tuple[ok: bool, roomId: string, errcode: string] =
  let normalizedUser = normalizeUserId(userId)
  let resolved = state.resolveRoom(roomIdOrAlias)
  if not resolved.ok:
    return (false, "", "M_NOT_FOUND")
  if resolved.roomId notin state.rooms:
    return (false, "", "M_NOT_FOUND")
  var room = state.rooms[resolved.roomId]
  room.members[normalizedUser] = "leave"
  state.rooms[resolved.roomId] = room
  discard state.putEvent(
    roomId = resolved.roomId,
    sender = normalizedUser,
    eventType = "m.room.member",
    stateKey = some(normalizedUser),
    content = %*{"membership": "leave"},
  )
  (true, resolved.roomId, "")

proc inviteUser*(state: ApiRouterState; inviter, targetUser, roomIdOrAlias: string): tuple[ok: bool, roomId: string, errcode: string] =
  let normalizedInviter = normalizeUserId(inviter)
  let normalizedTarget = normalizeUserId(targetUser)
  if normalizedTarget notin state.users:
    return (false, "", "M_NOT_FOUND")
  let resolved = state.resolveRoom(roomIdOrAlias)
  if not resolved.ok:
    return (false, "", "M_NOT_FOUND")
  if not state.userCanAccessRoom(normalizedInviter, resolved.roomId):
    return (false, "", "M_FORBIDDEN")
  var room = state.rooms[resolved.roomId]
  room.members[normalizedTarget] = "invite"
  state.rooms[resolved.roomId] = room
  discard state.putEvent(
    roomId = resolved.roomId,
    sender = normalizedInviter,
    eventType = "m.room.member",
    stateKey = some(normalizedTarget),
    content = %*{"membership": "invite"},
  )
  (true, resolved.roomId, "")

proc setRoomVisibility*(state: ApiRouterState; roomIdOrAlias, visibility: string): tuple[ok: bool, roomId: string] =
  let resolved = state.resolveRoom(roomIdOrAlias)
  if not resolved.ok:
    return (false, "")
  var room = state.rooms[resolved.roomId]
  room.visibility = visibility.strip().toLowerAscii()
  state.rooms[resolved.roomId] = room
  (true, resolved.roomId)

proc getRoomVisibility*(state: ApiRouterState; roomIdOrAlias: string): tuple[ok: bool, visibility: string] =
  let resolved = state.resolveRoom(roomIdOrAlias)
  if not resolved.ok:
    return (false, "")
  let room = state.rooms[resolved.roomId]
  (true, room.visibility)

proc setAlias*(state: ApiRouterState; roomIdOrAlias, aliasValue: string): tuple[ok: bool, roomId: string, errcode: string] =
  let alias = normalizeRoomAlias(aliasValue)
  if alias.len == 0:
    return (false, "", "M_INVALID_PARAM")
  if alias in state.roomAliases:
    return (false, "", "M_ROOM_IN_USE")
  let resolved = state.resolveRoom(roomIdOrAlias)
  if not resolved.ok:
    return (false, "", "M_NOT_FOUND")
  state.roomAliases[alias] = resolved.roomId
  var room = state.rooms[resolved.roomId]
  if room.canonicalAlias.len == 0:
    room.canonicalAlias = alias
  state.rooms[resolved.roomId] = room
  (true, resolved.roomId, "")

proc getAlias*(state: ApiRouterState; aliasValue: string): tuple[ok: bool, roomId: string] =
  let alias = normalizeRoomAlias(aliasValue)
  if alias in state.roomAliases:
    return (true, state.roomAliases[alias])
  (false, "")

proc deleteAlias*(state: ApiRouterState; aliasValue: string): bool =
  let alias = normalizeRoomAlias(aliasValue)
  if alias notin state.roomAliases:
    return false
  let roomId = state.roomAliases[alias]
  state.roomAliases.del(alias)
  if roomId in state.rooms:
    var room = state.rooms[roomId]
    if room.canonicalAlias == alias:
      room.canonicalAlias = ""
      state.rooms[roomId] = room
  true

proc aliasesForRoom*(state: ApiRouterState; roomIdOrAlias: string): seq[string] =
  let resolved = state.resolveRoom(roomIdOrAlias)
  if not resolved.ok:
    return @[]
  result = @[]
  for alias, rid in state.roomAliases.pairs:
    if rid == resolved.roomId:
      result.add(alias)

proc isJoined*(state: ApiRouterState; userId, roomId: string): bool =
  let normalizedUser = normalizeUserId(userId)
  if roomId notin state.rooms:
    return false
  let room = state.rooms[roomId]
  room.members.getOrDefault(normalizedUser) == "join"

proc joinedRoomsFor*(state: ApiRouterState; userId: string): seq[string] =
  let normalizedUser = normalizeUserId(userId)
  result = @[]
  for roomId, room in state.rooms.pairs:
    if room.members.getOrDefault(normalizedUser) == "join":
      result.add(roomId)

proc joinedMembersFor*(state: ApiRouterState; roomIdOrAlias: string): seq[string] =
  let resolved = state.resolveRoom(roomIdOrAlias)
  if not resolved.ok:
    return @[]
  result = @[]
  let room = state.rooms[resolved.roomId]
  for userId, membership in room.members.pairs:
    if membership == "join":
      result.add(userId)

proc roomTimeline*(state: ApiRouterState; roomIdOrAlias: string; limit = 50): seq[RoomEventRecord] =
  let resolved = state.resolveRoom(roomIdOrAlias)
  if not resolved.ok:
    return @[]
  let room = state.rooms[resolved.roomId]
  let maxTake = max(limit, 0)
  if maxTake == 0:
    return @[]
  var start = 0
  if room.timeline.len > maxTake:
    start = room.timeline.len - maxTake
  result = @[]
  for idx in start ..< room.timeline.len:
    let eventId = room.timeline[idx]
    if eventId in state.events:
      result.add(state.events[eventId])

proc roomState*(state: ApiRouterState; roomIdOrAlias: string): seq[RoomEventRecord] =
  let resolved = state.resolveRoom(roomIdOrAlias)
  if not resolved.ok:
    return @[]
  let room = state.rooms[resolved.roomId]
  result = @[]
  for _, eventId in room.stateEvents.pairs:
    if eventId in state.events:
      result.add(state.events[eventId])

proc roomStateEvent*(state: ApiRouterState; roomIdOrAlias, eventType, stateKey: string): tuple[ok: bool, event: RoomEventRecord] =
  let resolved = state.resolveRoom(roomIdOrAlias)
  if not resolved.ok:
    return (false, RoomEventRecord())
  let room = state.rooms[resolved.roomId]
  let key = stateEventKey(eventType, stateKey)
  if key in room.stateEvents:
    let eventId = room.stateEvents[key]
    if eventId in state.events:
      return (true, state.events[eventId])
  (false, RoomEventRecord())

proc getEvent*(state: ApiRouterState; eventId: string): tuple[ok: bool, event: RoomEventRecord] =
  if eventId in state.events:
    return (true, state.events[eventId])
  (false, RoomEventRecord())

proc streamEventsForUser*(state: ApiRouterState; userId: string; since = 0): seq[RoomEventRecord] =
  let normalizedUser = normalizeUserId(userId)
  result = @[]
  let lowerBound = max(since, 0)
  for eventId in state.stream:
    if eventId notin state.events:
      continue
    let event = state.events[eventId]
    if event.streamPos <= lowerBound:
      continue
    if state.isJoined(normalizedUser, event.roomId):
      result.add(event)
      continue
    if event.eventType == "m.room.member" and event.stateKey.isSome:
      if normalizeUserId(event.stateKey.get()) == normalizedUser:
        result.add(event)

proc publicRooms*(state: ApiRouterState): seq[RoomRecord] =
  result = @[]
  for _, room in state.rooms.pairs:
    if room.visibility == "public":
      result.add(room)

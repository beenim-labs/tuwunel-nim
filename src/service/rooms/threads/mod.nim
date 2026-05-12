const
  RustPath* = "service/rooms/threads/mod.rs"
  RustCrate* = "service"
  MaxThreadHops* = 3

import std/[algorithm, json, options, tables]

type
  ThreadResult* = tuple[ok: bool, errcode: string, message: string]

  ThreadEvent* = object
    eventId*: string
    roomId*: string
    sender*: string
    streamPos*: uint64
    content*: JsonNode
    unsigned*: JsonNode
    transactionId*: string

  ThreadService* = object
    events*: Table[string, ThreadEvent]
    roomEvents*: Table[string, seq[string]]
    participants*: Table[string, seq[string]]

proc initThreadService*(): ThreadService =
  ThreadService(
    events: initTable[string, ThreadEvent](),
    roomEvents: initTable[string, seq[string]](),
    participants: initTable[string, seq[string]](),
  )

proc okResult(): ThreadResult =
  (true, "", "")

proc threadError(errcode, message: string): ThreadResult =
  (false, errcode, message)

proc copyOrEmpty(node: JsonNode): JsonNode =
  if node.isNil:
    newJObject()
  else:
    node.copy()

proc eventFormat*(event: ThreadEvent): JsonNode =
  result = %*{
    "event_id": event.eventId,
    "room_id": event.roomId,
    "sender": event.sender,
    "content": copyOrEmpty(event.content),
  }
  if not event.unsigned.isNil and event.unsigned.kind == JObject and event.unsigned.len > 0:
    result["unsigned"] = event.unsigned.copy()
  if event.transactionId.len > 0:
    result["unsigned"] = result{"unsigned"}.copyOrEmpty()
    result["unsigned"]["transaction_id"] = %event.transactionId

proc relationFromContent(content: JsonNode): tuple[ok: bool, relType: string, eventId: string] =
  if content.isNil or content.kind != JObject:
    return (false, "", "")
  let relates = content{"m.relates_to"}
  if relates.isNil or relates.kind != JObject:
    return (false, "", "")
  let relType = relates{"rel_type"}.getStr("")
  let eventId = relates{"event_id"}.getStr("")
  if relType.len == 0 or eventId.len == 0:
    return (false, "", "")
  (true, relType, eventId)

proc addEvent*(service: var ThreadService; event: ThreadEvent) =
  service.events[event.eventId] = ThreadEvent(
    eventId: event.eventId,
    roomId: event.roomId,
    sender: event.sender,
    streamPos: event.streamPos,
    content: copyOrEmpty(event.content),
    unsigned: copyOrEmpty(event.unsigned),
    transactionId: event.transactionId,
  )
  var roomEvents = service.roomEvents.getOrDefault(event.roomId, @[])
  if event.eventId notin roomEvents:
    roomEvents.add(event.eventId)
  for i in 1 ..< roomEvents.len:
    let eventId = roomEvents[i]
    let streamPos = service.events[eventId].streamPos
    var j = i
    while j > 0 and service.events[roomEvents[j - 1]].streamPos > streamPos:
      roomEvents[j] = roomEvents[j - 1]
      dec j
    roomEvents[j] = eventId
  service.roomEvents[event.roomId] = roomEvents

proc getThreadId*(service: ThreadService; event: ThreadEvent): Option[string] =
  var relation = relationFromContent(event.content)
  if not relation.ok:
    return none(string)
  for _ in 0 ..< MaxThreadHops:
    if relation.relType == "m.thread":
      return some(relation.eventId)
    if relation.eventId notin service.events:
      return none(string)
    relation = relationFromContent(service.events[relation.eventId].content)
    if not relation.ok:
      return none(string)
  none(string)

proc getThreadIdForEvent*(service: ThreadService; eventId: string): Option[string] =
  if eventId notin service.events:
    return none(string)
  service.getThreadId(service.events[eventId])

proc addUnique(values: var seq[string]; value: string) =
  if value notin values:
    values.add(value)

proc updateParticipants*(service: var ThreadService; rootEventId: string; participants: openArray[string]): ThreadResult =
  var users: seq[string] = @[]
  for userId in participants:
    users.addUnique(userId)
  users.sort(system.cmp[string])
  service.participants[rootEventId] = users
  okResult()

proc getParticipants*(service: ThreadService; rootEventId: string): tuple[ok: bool, users: seq[string]] =
  if rootEventId notin service.participants:
    return (false, @[])
  (true, service.participants[rootEventId])

proc addToThread*(service: var ThreadService; rootEventId: string; event: ThreadEvent): ThreadResult =
  if rootEventId notin service.events:
    return threadError("M_INVALID_PARAM", "Thread root not found.")

  var eventCopy = event
  service.addEvent(eventCopy)

  var root = service.events[rootEventId]
  if root.unsigned.isNil or root.unsigned.kind != JObject:
    root.unsigned = newJObject()
  if not root.unsigned.hasKey("m.relations") or root.unsigned["m.relations"].kind != JObject:
    root.unsigned["m.relations"] = newJObject()
  var threadRelation =
    if root.unsigned["m.relations"].hasKey("m.thread") and
        root.unsigned["m.relations"]["m.thread"].kind == JObject:
      root.unsigned["m.relations"]["m.thread"].copy()
    else:
      newJObject()
  threadRelation["latest_event"] = eventFormat(eventCopy)
  threadRelation["count"] = %(threadRelation{"count"}.getInt(0) + 1)
  threadRelation["current_user_participated"] = %true
  root.unsigned["m.relations"]["m.thread"] = threadRelation
  service.events[rootEventId] = root

  var users: seq[string] = @[]
  let existing = service.getParticipants(rootEventId)
  if existing.ok:
    users = existing.users
  else:
    users.add(root.sender)
  users.addUnique(eventCopy.sender)
  service.updateParticipants(rootEventId, users)

proc threadsUntil*(
  service: ThreadService;
  userId, roomId: string;
  beforeCount: uint64;
): seq[ThreadEvent] =
  discard userId
  result = @[]
  let roomEventIds = service.roomEvents.getOrDefault(roomId, @[])
  for eventId in roomEventIds:
    if eventId in service.participants and eventId in service.events:
      let event = service.events[eventId]
      if event.streamPos < beforeCount:
        var visible = event
        if visible.sender != userId:
          visible.transactionId = ""
        result.add(visible)
  result.sort(proc(a, b: ThreadEvent): int = cmp(b.streamPos, a.streamPos))

proc deleteAllRoomsThreads*(service: var ThreadService; roomId: string): ThreadResult =
  var deleteRoots: seq[string] = @[]
  for rootEventId in service.participants.keys:
    if rootEventId in service.events and service.events[rootEventId].roomId == roomId:
      deleteRoots.add(rootEventId)
  for rootEventId in deleteRoots:
    service.participants.del(rootEventId)
  okResult()

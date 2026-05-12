const
  RustPath* = "service/pusher/suppressed.rs"
  RustCrate* = "service"
  SuppressedMaxEventsPerRoom* = 512
  SuppressedMaxEventsPerPushkey* = 4096
  SuppressedMaxRoomsPerPushkey* = 256

import std/tables

type
  SuppressedEvent* = object
    pduId*: string
    insertedAtMs*: uint64

  PushkeyQueue* = object
    rooms*: Table[string, seq[SuppressedEvent]]
    totalEvents*: int

  SuppressedQueue* = object
    users*: Table[string, Table[string, PushkeyQueue]]

  SuppressedRoomDrain* = tuple[roomId: string, pduIds: seq[string]]
  SuppressedPushDrain* = tuple[pushkey: string, rooms: seq[SuppressedRoomDrain]]

proc initPushkeyQueue*(): PushkeyQueue =
  PushkeyQueue(rooms: initTable[string, seq[SuppressedEvent]](), totalEvents: 0)

proc initSuppressedQueue*(): SuppressedQueue =
  SuppressedQueue(users: initTable[string, Table[string, PushkeyQueue]]())

proc drainRoom(queue: seq[SuppressedEvent]): seq[string] =
  result = @[]
  for event in queue:
    result.add(event.pduId)

proc queueSuppressedPush*(
  queue: var SuppressedQueue;
  userId, pushkey, roomId, pduId: string;
  insertedAtMs = 0'u64;
): bool =
  var userEntry =
    if userId in queue.users:
      queue.users[userId]
    else:
      initTable[string, PushkeyQueue]()
  var pushEntry =
    if pushkey in userEntry:
      userEntry[pushkey]
    else:
      initPushkeyQueue()

  if roomId notin pushEntry.rooms and pushEntry.rooms.len >= SuppressedMaxRoomsPerPushkey:
    return false

  var roomQueue =
    if roomId in pushEntry.rooms:
      pushEntry.rooms[roomId]
    else:
      @[]

  if roomQueue.len > 0 and roomQueue[^1].pduId == pduId:
    return false

  if pushEntry.totalEvents >= SuppressedMaxEventsPerPushkey and roomQueue.len == 0:
    return false

  while roomQueue.len >= SuppressedMaxEventsPerRoom or
      pushEntry.totalEvents >= SuppressedMaxEventsPerPushkey:
    if roomQueue.len == 0:
      break
    roomQueue.delete(0)
    pushEntry.totalEvents = max(pushEntry.totalEvents - 1, 0)

  roomQueue.add(SuppressedEvent(pduId: pduId, insertedAtMs: insertedAtMs))
  inc pushEntry.totalEvents
  pushEntry.rooms[roomId] = roomQueue
  userEntry[pushkey] = pushEntry
  queue.users[userId] = userEntry
  true

proc takeSuppressedForPushkey*(
  queue: var SuppressedQueue;
  userId, pushkey: string;
): seq[SuppressedRoomDrain] =
  result = @[]
  if userId notin queue.users:
    return
  var userEntry = queue.users[userId]
  if pushkey notin userEntry:
    return
  let pushEntry = userEntry[pushkey]
  userEntry.del(pushkey)
  for roomId, events in pushEntry.rooms:
    result.add((roomId, drainRoom(events)))
  if userEntry.len == 0:
    queue.users.del(userId)
  else:
    queue.users[userId] = userEntry

proc takeSuppressedForUser*(
  queue: var SuppressedQueue;
  userId: string;
): seq[SuppressedPushDrain] =
  result = @[]
  if userId notin queue.users:
    return
  let userEntry = queue.users[userId]
  queue.users.del(userId)
  for pushkey, pushEntry in userEntry:
    var rooms: seq[SuppressedRoomDrain] = @[]
    for roomId, events in pushEntry.rooms:
      rooms.add((roomId, drainRoom(events)))
    result.add((pushkey, rooms))

proc clearSuppressedRoom*(queue: var SuppressedQueue; userId, roomId: string): int =
  if userId notin queue.users:
    return 0
  var userEntry = queue.users[userId]
  var removed = 0
  var emptyPushkeys: seq[string] = @[]
  for pushkey, pushEntryValue in userEntry:
    var pushEntry = pushEntryValue
    if roomId in pushEntry.rooms:
      let count = pushEntry.rooms[roomId].len
      removed += count
      pushEntry.totalEvents = max(pushEntry.totalEvents - count, 0)
      pushEntry.rooms.del(roomId)
    if pushEntry.rooms.len == 0:
      emptyPushkeys.add(pushkey)
    else:
      userEntry[pushkey] = pushEntry
  for pushkey in emptyPushkeys:
    userEntry.del(pushkey)
  if userEntry.len == 0:
    queue.users.del(userId)
  else:
    queue.users[userId] = userEntry
  removed

proc clearSuppressedPushkey*(queue: var SuppressedQueue; userId, pushkey: string): int =
  if userId notin queue.users:
    return 0
  var userEntry = queue.users[userId]
  if pushkey notin userEntry:
    return 0
  let removed = userEntry[pushkey].totalEvents
  userEntry.del(pushkey)
  if userEntry.len == 0:
    queue.users.del(userId)
  else:
    queue.users[userId] = userEntry
  removed

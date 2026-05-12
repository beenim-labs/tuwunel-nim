const
  RustPath* = "api/client/sync/v5/selector.rs"
  RustCrate* = "api"

import std/[algorithm, json, options, tables]

import api/client/sync/v5/filter

type
  RoomDetailConfig* = object
    timelineLimit*: int
    requiredState*: seq[tuple[eventType: string, stateKey: string]]

  SyncListConfig* = object
    filters*: Option[ListFilters]
    ranges*: seq[tuple[first: int, last: int]]
    roomDetails*: RoomDetailConfig

  WindowRoom* = object
    roomId*: string
    membership*: Option[string]
    lists*: seq[string]
    ranked*: int
    lastCount*: uint64

  ConnectionRoom* = object
    roomsince*: uint64

  SyncConnection* = object
    nextBatch*: uint64
    globalSince*: uint64
    lists*: OrderedTable[string, SyncListConfig]
    rooms*: Table[string, ConnectionRoom]
    subscriptions*: OrderedTable[string, RoomDetailConfig]

  ResponseList* = object
    count*: int

proc initSyncConnection*(nextBatch = 0'u64; globalSince = 0'u64): SyncConnection =
  SyncConnection(
    nextBatch: nextBatch,
    globalSince: globalSince,
    lists: initOrderedTable[string, SyncListConfig](),
    rooms: initTable[string, ConnectionRoom](),
    subscriptions: initOrderedTable[string, RoomDetailConfig](),
  )

proc roomSort*(a, b: WindowRoom): int =
  result = system.cmp(b.lastCount, a.lastCount)
  if result == 0:
    result = system.cmp(a.roomId, b.roomId)

proc responseLists*(rooms: openArray[WindowRoom]): OrderedTable[string, ResponseList] =
  result = initOrderedTable[string, ResponseList]()
  for room in rooms:
    for listId in room.lists:
      var list = result.getOrDefault(listId, ResponseList())
      inc list.count
      result[listId] = list

proc selectRooms*(
  conn: var SyncConnection;
  rooms: openArray[RoomFilterMeta];
  lastCounts: Table[string, uint64]
): seq[WindowRoom] =
  result = @[]
  for room in rooms:
    if not filterRoomMeta(room):
      continue
    var matchedLists: seq[string] = @[]
    for listId, list in conn.lists:
      if list.filters.isNone or filterRoom(list.filters.get(), room):
        matchedLists.add(listId)
    if matchedLists.len == 0:
      continue
    let lastCount = lastCounts.getOrDefault(room.roomId, 0'u64)
    result.add(WindowRoom(
      roomId: room.roomId,
      membership: room.membership,
      lists: matchedLists,
      lastCount: lastCount,
    ))
    if not conn.rooms.hasKey(room.roomId):
      conn.rooms[room.roomId] = ConnectionRoom()

  result.sort(roomSort)
  for idx in 0 ..< result.len:
    result[idx].ranked = idx

proc requestedRange*(ranges: openArray[tuple[first: int, last: int]]; maxIndex: int): tuple[first: int, last: int] =
  if maxIndex < 0:
    return (0, -1)
  if ranges.len == 0:
    return (0, maxIndex)
  (max(0, min(maxIndex, ranges[0].first)), max(0, min(maxIndex, ranges[0].last)))

proc window*(
  conn: SyncConnection;
  rooms: openArray[WindowRoom]
): OrderedTable[string, WindowRoom] =
  result = initOrderedTable[string, WindowRoom]()
  for listId, list in conn.lists:
    let range = requestedRange(list.ranges, rooms.len - 1)
    if range.last >= range.first:
      var matchedIndex = 0
      for room in rooms:
        if listId notin room.lists:
          continue
        if matchedIndex >= range.first and matchedIndex <= range.last:
          let connRoom = conn.rooms.getOrDefault(room.roomId, ConnectionRoom())
          if connRoom.roomsince == 0 or room.lastCount > connRoom.roomsince:
            result[room.roomId] = room
        inc matchedIndex
  for roomId in conn.subscriptions.keys:
    if not result.hasKey(roomId):
      result[roomId] = WindowRoom(roomId: roomId, ranked: high(int), lists: @[], lastCount: 0'u64)

proc responseListJson*(list: ResponseList; roomIds: openArray[string]; first = 0; last = -1): JsonNode =
  let effectiveLast =
    if last < 0:
      max(0, roomIds.len - 1)
    else:
      last
  result = %*{
    "count": list.count,
    "ops": [
      {
        "op": "SYNC",
        "range": [first, effectiveLast],
        "room_ids": roomIds
      }
    ]
  }

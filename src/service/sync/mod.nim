const
  RustPath* = "service/sync/mod.rs"
  RustCrate* = "service"

import std/[algorithm, options, tables]

import api/client/sync/v5/filter
import api/client/sync/v5/selector
import service/sync/watch as sync_watch

export filter, selector, sync_watch

type
  ConnectionKey* = object
    userId*: string
    deviceId*: string
    connId*: string

  Room* = object
    roomsince*: uint64

  AccountDataExtension* = object
    enabled*: Option[bool]
    lists*: seq[string]
    rooms*: seq[string]

  ReceiptsExtension* = object
    enabled*: Option[bool]
    rooms*: seq[string]
    lists*: seq[string]

  TypingExtension* = object
    enabled*: Option[bool]
    rooms*: seq[string]
    lists*: seq[string]

  ToDeviceExtension* = object
    enabled*: Option[bool]
    since*: string

  E2eeExtension* = object
    enabled*: Option[bool]

  SyncExtensionsConfig* = object
    accountData*: AccountDataExtension
    receipts*: ReceiptsExtension
    typing*: TypingExtension
    toDevice*: ToDeviceExtension
    e2ee*: E2eeExtension

  Connection* = object
    globalsince*: uint64
    nextBatch*: uint64
    lists*: OrderedTable[string, SyncListConfig]
    extensions*: SyncExtensionsConfig
    subscriptions*: OrderedTable[string, RoomDetailConfig]
    rooms*: Table[string, Room]

  SyncUpdateRequest* = object
    lists*: OrderedTable[string, SyncListConfig]
    roomSubscriptions*: OrderedTable[string, RoomDetailConfig]
    extensions*: SyncExtensionsConfig

  SyncService* = object
    loadedConnections*: Table[string, Connection]
    storedConnections*: Table[string, Connection]
    keyIndex*: Table[string, ConnectionKey]

proc intoConnectionKey*(userId: string; deviceId = ""; connId = ""): ConnectionKey =
  ConnectionKey(userId: userId, deviceId: deviceId, connId: connId)

proc storageId*(key: ConnectionKey): string =
  key.userId & "\0" & key.deviceId & "\0" & key.connId

proc cmpConnectionKey*(a, b: ConnectionKey): int =
  result = cmp(a.userId, b.userId)
  if result == 0:
    result = cmp(a.deviceId, b.deviceId)
  if result == 0:
    result = cmp(a.connId, b.connId)

proc initConnection*(
  globalsince = 0'u64;
  nextBatch = 0'u64;
): Connection =
  Connection(
    globalsince: globalsince,
    nextBatch: nextBatch,
    lists: initOrderedTable[string, SyncListConfig](),
    extensions: SyncExtensionsConfig(),
    subscriptions: initOrderedTable[string, RoomDetailConfig](),
    rooms: initTable[string, Room](),
  )

proc initSyncUpdateRequest*(): SyncUpdateRequest =
  SyncUpdateRequest(
    lists: initOrderedTable[string, SyncListConfig](),
    roomSubscriptions: initOrderedTable[string, RoomDetailConfig](),
    extensions: SyncExtensionsConfig(),
  )

proc initSyncService*(): SyncService =
  SyncService(
    loadedConnections: initTable[string, Connection](),
    storedConnections: initTable[string, Connection](),
    keyIndex: initTable[string, ConnectionKey](),
  )

proc matchesFilter(key: ConnectionKey; userId, deviceId, connId: Option[string]): bool =
  if userId.isSome and key.userId != userId.get():
    return false
  if deviceId.isSome and key.deviceId != deviceId.get():
    return false
  if connId.isSome and key.connId != connId.get():
    return false
  true

proc rememberKey(service: var SyncService; key: ConnectionKey) =
  service.keyIndex[storageId(key)] = key

proc store*(service: var SyncService; key: ConnectionKey; conn: Connection) =
  let id = storageId(key)
  service.storedConnections[id] = conn
  service.loadedConnections[id] = conn
  service.keyIndex[id] = key

proc store*(conn: Connection; service: var SyncService; key: ConnectionKey) =
  service.store(key, conn)

proc loadOrInitConnection*(service: var SyncService; key: ConnectionKey): Connection =
  let id = storageId(key)
  service.rememberKey(key)
  if id in service.loadedConnections:
    return service.loadedConnections[id]
  if id in service.storedConnections:
    let conn = service.storedConnections[id]
    service.loadedConnections[id] = conn
    return conn
  let conn = initConnection()
  service.loadedConnections[id] = conn
  conn

proc loadConnection*(service: var SyncService; key: ConnectionKey): tuple[ok: bool, conn: Connection] =
  let id = storageId(key)
  service.rememberKey(key)
  if id in service.loadedConnections:
    return (true, service.loadedConnections[id])
  if id in service.storedConnections:
    let conn = service.storedConnections[id]
    service.loadedConnections[id] = conn
    return (true, conn)
  (false, initConnection())

proc getLoadedConnection*(service: SyncService; key: ConnectionKey): tuple[ok: bool, conn: Connection] =
  let id = storageId(key)
  if id in service.loadedConnections:
    return (true, service.loadedConnections[id])
  (false, initConnection())

proc isConnectionLoaded*(service: SyncService; key: ConnectionKey): bool =
  storageId(key) in service.loadedConnections

proc isConnectionStored*(service: SyncService; key: ConnectionKey): bool =
  storageId(key) in service.storedConnections

proc dropConnection*(service: var SyncService; key: ConnectionKey) =
  let id = storageId(key)
  service.loadedConnections.del(id)
  service.storedConnections.del(id)
  service.keyIndex.del(id)

proc listLoadedConnections*(service: SyncService): seq[ConnectionKey] =
  result = @[]
  for id in service.loadedConnections.keys:
    if id in service.keyIndex:
      result.add(service.keyIndex[id])
  result.sort(cmpConnectionKey)

proc listStoredConnections*(service: SyncService): seq[ConnectionKey] =
  result = @[]
  for id in service.storedConnections.keys:
    if id in service.keyIndex:
      result.add(service.keyIndex[id])
  result.sort(cmpConnectionKey)

proc clearConnections*(
  service: var SyncService;
  userId: Option[string] = none(string);
  deviceId: Option[string] = none(string);
  connId: Option[string] = none(string);
): int =
  var ids: seq[string] = @[]
  for id, key in service.keyIndex:
    if key.matchesFilter(userId, deviceId, connId):
      ids.add(id)
  for id in ids:
    service.loadedConnections.del(id)
    service.storedConnections.del(id)
    service.keyIndex.del(id)
  ids.len

proc updateRoomsPrologue*(conn: var Connection; retardSince: Option[uint64]) =
  if retardSince.isNone:
    return
  let since = retardSince.get()
  for room in conn.rooms.mvalues:
    if room.roomsince > since:
      room.roomsince = since

proc updateRoomsEpilogue*(conn: var Connection; window: openArray[string]) =
  for roomId in window:
    var room = conn.rooms.getOrDefault(roomId, Room())
    room.roomsince = conn.nextBatch
    conn.rooms[roomId] = room

proc replaceIfPresent[T](value: Option[T]; cached: var Option[T]) =
  if value.isSome:
    cached = value

proc replaceIfNotEmpty[T](value: openArray[T]; cached: var seq[T]) =
  if value.len == 0:
    return
  cached.setLen(0)
  for item in value:
    cached.add(item)

proc updateCacheList*(requestList: SyncListConfig; cached: var SyncListConfig) =
  replaceIfNotEmpty(requestList.roomDetails.requiredState, cached.roomDetails.requiredState)
  if requestList.roomDetails.timelineLimit > 0:
    cached.roomDetails.timelineLimit = requestList.roomDetails.timelineLimit
  replaceIfNotEmpty(requestList.ranges, cached.ranges)

  if requestList.filters.isSome and cached.filters.isNone:
    cached.filters = requestList.filters
  elif requestList.filters.isSome and cached.filters.isSome:
    var filters = cached.filters.get()
    let request = requestList.filters.get()
    replaceIfPresent(request.isDm, filters.isDm)
    replaceIfPresent(request.isEncrypted, filters.isEncrypted)
    replaceIfPresent(request.isInvite, filters.isInvite)
    replaceIfNotEmpty(request.roomTypes, filters.roomTypes)
    replaceIfNotEmpty(request.notRoomTypes, filters.notRoomTypes)
    replaceIfNotEmpty(request.tags, filters.tags)
    replaceIfNotEmpty(request.notTags, filters.notTags)
    replaceIfNotEmpty(request.spaces, filters.spaces)
    cached.filters = some(filters)

proc updateCacheLists*(request: SyncUpdateRequest; conn: var Connection) =
  for listId, requestList in request.lists:
    if listId in conn.lists:
      var cached = conn.lists[listId]
      updateCacheList(requestList, cached)
      conn.lists[listId] = cached
    else:
      conn.lists[listId] = requestList

proc updateCacheSubscriptions*(request: SyncUpdateRequest; conn: var Connection) =
  conn.subscriptions.clear()
  for roomId, config in request.roomSubscriptions:
    conn.subscriptions[roomId] = config

proc updateCacheAccountData*(request: AccountDataExtension; cached: var AccountDataExtension) =
  replaceIfPresent(request.enabled, cached.enabled)
  replaceIfNotEmpty(request.lists, cached.lists)
  replaceIfNotEmpty(request.rooms, cached.rooms)

proc updateCacheReceipts*(request: ReceiptsExtension; cached: var ReceiptsExtension) =
  replaceIfPresent(request.enabled, cached.enabled)
  replaceIfNotEmpty(request.rooms, cached.rooms)
  replaceIfNotEmpty(request.lists, cached.lists)

proc updateCacheTyping*(request: TypingExtension; cached: var TypingExtension) =
  replaceIfPresent(request.enabled, cached.enabled)
  replaceIfNotEmpty(request.rooms, cached.rooms)
  replaceIfNotEmpty(request.lists, cached.lists)

proc updateCacheToDevice*(request: ToDeviceExtension; cached: var ToDeviceExtension) =
  replaceIfPresent(request.enabled, cached.enabled)
  cached.since = request.since

proc updateCacheE2ee*(request: E2eeExtension; cached: var E2eeExtension) =
  replaceIfPresent(request.enabled, cached.enabled)

proc updateCacheExtensions*(request: SyncUpdateRequest; conn: var Connection) =
  updateCacheAccountData(request.extensions.accountData, conn.extensions.accountData)
  updateCacheReceipts(request.extensions.receipts, conn.extensions.receipts)
  updateCacheTyping(request.extensions.typing, conn.extensions.typing)
  updateCacheToDevice(request.extensions.toDevice, conn.extensions.toDevice)
  updateCacheE2ee(request.extensions.e2ee, conn.extensions.e2ee)

proc updateCache*(conn: var Connection; request: SyncUpdateRequest) =
  updateCacheLists(request, conn)
  updateCacheSubscriptions(request, conn)
  updateCacheExtensions(request, conn)

proc watch*(
  service: SyncService;
  userId, deviceId: string;
  rooms: openArray[string];
  shortRoomIds: Table[string, string] = initTable[string, string]();
): SyncWatch =
  discard service
  registerSyncWatch(userId, deviceId, rooms, shortRoomIds)

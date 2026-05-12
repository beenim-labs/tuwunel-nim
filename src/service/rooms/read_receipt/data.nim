const
  RustPath* = "service/rooms/read_receipt/data.rs"
  RustCrate* = "service"

import std/[algorithm, json, strutils, tables]

type
  ReceiptResult* = tuple[ok: bool, errcode: string, message: string]

  ReceiptItem* = object
    userId*: string
    streamPos*: uint64
    event*: JsonNode

  StoredReceipt* = object
    roomId*: string
    streamPos*: uint64
    userId*: string
    threadKind*: string
    event*: JsonNode

  PrivateReadRecord* = object
    roomId*: string
    userId*: string
    threadKind*: string
    pduCount*: uint64

  ReadReceiptData* = object
    nextCount*: uint64
    readReceipts*: Table[string, StoredReceipt]
    privateReads*: Table[string, PrivateReadRecord]
    lastPrivateReadUpdate*: Table[string, uint64]
    pduEventIds*: Table[string, string]

proc initReadReceiptData*(): ReadReceiptData =
  ReadReceiptData(
    nextCount: 0'u64,
    readReceipts: initTable[string, StoredReceipt](),
    privateReads: initTable[string, PrivateReadRecord](),
    lastPrivateReadUpdate: initTable[string, uint64](),
    pduEventIds: initTable[string, string](),
  )

proc nextCount*(data: var ReadReceiptData): uint64 =
  inc data.nextCount
  data.nextCount

proc receiptStorageKey*(roomId: string; streamPos: uint64; userId, threadKind: string): string =
  roomId & "\0" & $streamPos & "\0" & userId & "\0" & threadKind

proc privateReadKey*(roomId, userId, threadKind: string): string =
  roomId & "\0" & userId & "\0" & threadKind

proc lastPrivateReadKey*(roomId, userId: string): string =
  roomId & "\0" & userId

proc pduEventKey*(roomId: string; pduCount: uint64): string =
  roomId & "\0" & $pduCount

proc eventThreadKind*(event: JsonNode): string =
  if event.isNil or event.kind != JObject:
    return ""
  let content = event{"content"}
  if content.isNil or content.kind != JObject:
    return ""
  for _, receiptTypes in content:
    if receiptTypes.kind != JObject:
      continue
    for _, users in receiptTypes:
      if users.kind != JObject:
        continue
      for _, receipt in users:
        if receipt.kind == JObject:
          return receipt{"thread_id"}.getStr("")
  ""

proc eventUserIds*(event: JsonNode): seq[string] =
  result = @[]
  if event.isNil or event.kind != JObject:
    return
  let content = event{"content"}
  if content.isNil or content.kind != JObject:
    return
  for _, receiptTypes in content:
    if receiptTypes.kind != JObject:
      continue
    for _, users in receiptTypes:
      if users.kind != JObject:
        continue
      for userId, _ in users:
        result.add(userId)
  result.sort(system.cmp[string])

proc stripRoomId(event: JsonNode): JsonNode =
  result = if event.isNil: newJObject() else: event.copy()
  if result.kind == JObject and result.hasKey("room_id"):
    result.delete("room_id")

proc readreceiptUpdate*(
  data: var ReadReceiptData;
  userId, roomId: string;
  event: JsonNode;
): uint64 =
  let threadKind = eventThreadKind(event)
  let legacyMatch = threadKind.len == 0
  var deleteKeys: seq[string] = @[]
  for key, record in data.readReceipts:
    if record.roomId == roomId and record.userId == userId and
        (record.threadKind == threadKind or (legacyMatch and record.threadKind.len == 0)):
      deleteKeys.add(key)
  for key in deleteKeys:
    data.readReceipts.del(key)

  let pos = data.nextCount()
  let storageKey = receiptStorageKey(roomId, pos, userId, threadKind)
  data.readReceipts[storageKey] = StoredReceipt(
    roomId: roomId,
    streamPos: pos,
    userId: userId,
    threadKind: threadKind,
    event: stripRoomId(event),
  )
  pos

proc readreceiptsSince*(
  data: ReadReceiptData;
  roomId: string;
  since: uint64;
  toPos: uint64 = high(uint64);
): seq[ReceiptItem] =
  result = @[]
  for record in data.readReceipts.values:
    if record.roomId == roomId and record.streamPos > since and record.streamPos <= toPos:
      result.add(ReceiptItem(
        userId: record.userId,
        streamPos: record.streamPos,
        event: stripRoomId(record.event),
      ))
  result.sort(proc(a, b: ReceiptItem): int =
    result = cmp(a.streamPos, b.streamPos)
    if result == 0:
      result = cmp(a.userId, b.userId)
  )

proc lastReceiptCount*(
  data: ReadReceiptData;
  roomId: string;
  since: uint64 = 0'u64;
  userId = "";
): tuple[ok: bool, count: uint64] =
  result = (false, 0'u64)
  for record in data.readReceipts.values:
    if record.roomId == roomId and record.streamPos > since and
        (userId.len == 0 or record.userId == userId) and
        (not result.ok or record.streamPos > result.count):
      result = (true, record.streamPos)

proc registerPduEvent*(data: var ReadReceiptData; roomId: string; pduCount: uint64; eventId: string) =
  data.pduEventIds[pduEventKey(roomId, pduCount)] = eventId

proc eventIdForPdu*(data: ReadReceiptData; roomId: string; pduCount: uint64): string =
  data.pduEventIds.getOrDefault(pduEventKey(roomId, pduCount), "$" & $pduCount)

proc clearThreadPrivateReads(data: var ReadReceiptData; roomId, userId: string) =
  var deleteKeys: seq[string] = @[]
  for key, record in data.privateReads:
    if record.roomId == roomId and record.userId == userId and record.threadKind.len > 0:
      deleteKeys.add(key)
  for key in deleteKeys:
    data.privateReads.del(key)

proc privateReadSet*(
  data: var ReadReceiptData;
  roomId, userId: string;
  pduCount: uint64;
  threadKind = "";
): uint64 =
  let update = data.nextCount()
  data.lastPrivateReadUpdate[lastPrivateReadKey(roomId, userId)] = update

  if threadKind.len == 0:
    data.clearThreadPrivateReads(roomId, userId)
  data.privateReads[privateReadKey(roomId, userId, threadKind)] = PrivateReadRecord(
    roomId: roomId,
    userId: userId,
    threadKind: threadKind,
    pduCount: pduCount,
  )
  update

proc privateReadGetCount*(data: ReadReceiptData; roomId, userId: string): tuple[ok: bool, count: uint64] =
  let key = privateReadKey(roomId, userId, "")
  if key notin data.privateReads:
    return (false, 0'u64)
  (true, data.privateReads[key].pduCount)

proc privateReadThreaded*(data: ReadReceiptData; roomId, userId: string): seq[PrivateReadRecord] =
  result = @[]
  for record in data.privateReads.values:
    if record.roomId == roomId and record.userId == userId and record.threadKind.len > 0:
      result.add(record)
  result.sort(proc(a, b: PrivateReadRecord): int = cmp(a.threadKind, b.threadKind))

proc lastPrivateReadUpdate*(data: ReadReceiptData; userId, roomId: string): uint64 =
  data.lastPrivateReadUpdate.getOrDefault(lastPrivateReadKey(roomId, userId), 0'u64)

proc deleteAllReadReceipts*(data: var ReadReceiptData; roomId: string): ReceiptResult =
  var receiptKeys: seq[string] = @[]
  for key, record in data.readReceipts:
    if record.roomId == roomId:
      receiptKeys.add(key)
  for key in receiptKeys:
    data.readReceipts.del(key)

  var privateKeys: seq[string] = @[]
  for key, record in data.privateReads:
    if record.roomId == roomId:
      privateKeys.add(key)
  for key in privateKeys:
    data.privateReads.del(key)

  var lastKeys: seq[string] = @[]
  for key in data.lastPrivateReadUpdate.keys:
    if key.startsWith(roomId & "\0"):
      lastKeys.add(key)
  for key in lastKeys:
    data.lastPrivateReadUpdate.del(key)

  (true, "", "")

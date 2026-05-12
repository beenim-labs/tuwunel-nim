const
  RustPath* = "service/rooms/read_receipt/mod.rs"
  RustCrate* = "service"

import std/[json, tables]

import service/rooms/read_receipt/data

export data

type
  ReadReceiptService* = object
    db*: ReadReceiptData
    sentAppserviceEdus*: seq[JsonNode]
    flushedRooms*: seq[string]
    localUsers*: Table[string, bool]

proc initReadReceiptService*(): ReadReceiptService =
  ReadReceiptService(
    db: initReadReceiptData(),
    sentAppserviceEdus: @[],
    flushedRooms: @[],
    localUsers: initTable[string, bool](),
  )

proc setUserLocal*(service: var ReadReceiptService; userId: string; local: bool) =
  service.localUsers[userId] = local

proc userIsLocal(service: ReadReceiptService; userId: string): bool =
  service.localUsers.getOrDefault(userId, true)

proc readreceiptUpdate*(
  service: var ReadReceiptService;
  userId, roomId: string;
  event: JsonNode;
): uint64 =
  result = readreceiptUpdate(service.db, userId, roomId, event)
  var edu = if event.isNil: newJObject() else: event.copy()
  edu["room_id"] = %roomId
  service.sentAppserviceEdus.add(%*{
    "type": "m.receipt",
    "room_id": roomId,
    "content": edu{"content"},
  })
  if service.userIsLocal(userId):
    service.flushedRooms.add(roomId)

proc receiptThreadKindToField*(threadKind: string): string =
  if threadKind == "main":
    "main"
  elif threadKind.len > 0 and threadKind[0] == '$':
    threadKind
  else:
    ""

proc privateReadEvent*(eventId, userId, threadKind: string): JsonNode =
  var userEntry = newJObject()
  let field = receiptThreadKindToField(threadKind)
  if field.len > 0:
    userEntry["thread_id"] = %field
  var users = newJObject()
  users[userId] = userEntry
  var receiptTypes = newJObject()
  receiptTypes["m.read.private"] = users
  var content = newJObject()
  content[eventId] = receiptTypes
  %*{
    "type": "m.receipt",
    "content": content,
  }

proc privateReadGet*(
  service: ReadReceiptService;
  roomId, userId: string;
): seq[JsonNode] =
  result = @[]
  let legacy = privateReadGetCount(service.db, roomId, userId)
  if legacy.ok:
    result.add(privateReadEvent(eventIdForPdu(service.db, roomId, legacy.count), userId, ""))
  for record in privateReadThreaded(service.db, roomId, userId):
    result.add(privateReadEvent(
      eventIdForPdu(service.db, roomId, record.pduCount),
      userId,
      record.threadKind,
    ))

proc readreceiptsSince*(
  service: ReadReceiptService;
  roomId: string;
  since: uint64;
  toPos: uint64 = high(uint64);
): seq[ReceiptItem] =
  readreceiptsSince(service.db, roomId, since, toPos)

proc privateReadSet*(
  service: var ReadReceiptService;
  roomId, userId: string;
  count: uint64;
  threadKind = "";
): uint64 =
  privateReadSet(service.db, roomId, userId, count, threadKind)

proc privateReadGetCount*(
  service: ReadReceiptService;
  roomId, userId: string;
): tuple[ok: bool, count: uint64] =
  privateReadGetCount(service.db, roomId, userId)

proc lastPrivateReadUpdate*(service: ReadReceiptService; userId, roomId: string): uint64 =
  lastPrivateReadUpdate(service.db, userId, roomId)

proc lastReceiptCount*(
  service: ReadReceiptService;
  roomId: string;
  userId = "";
  since = 0'u64;
): tuple[ok: bool, count: uint64] =
  lastReceiptCount(service.db, roomId, since, userId)

proc deleteAllReadReceipts*(service: var ReadReceiptService; roomId: string): ReceiptResult =
  deleteAllReadReceipts(service.db, roomId)

proc packReceipts*(receipts: openArray[JsonNode]): JsonNode =
  var content = newJObject()
  for event in receipts:
    if event.isNil or event.kind != JObject:
      continue
    let eventContent = event{"content"}
    if eventContent.isNil or eventContent.kind != JObject:
      continue
    for eventId, receiptTypes in eventContent:
      content[eventId] = if receiptTypes.isNil: newJObject() else: receiptTypes.copy()
  %*{
    "type": "m.receipt",
    "content": content,
  }

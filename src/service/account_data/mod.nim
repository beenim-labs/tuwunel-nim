const
  RustPath* = "service/account_data/mod.rs"
  RustCrate* = "service"

import std/[algorithm, json, tables]

type
  AccountDataResult* = tuple[ok: bool, err: string]
  AccountDataFetchResult* = tuple[ok: bool, event: JsonNode, err: string]
  AccountDataCountResult* = tuple[ok: bool, count: uint64, err: string]

  AccountDataRecord* = object
    roomId*: string
    userId*: string
    eventType*: string
    streamPos*: uint64
    event*: JsonNode

  AccountDataStore* = object
    nextCount*: uint64
    records*: Table[string, AccountDataRecord]

proc initAccountDataStore*(): AccountDataStore =
  AccountDataStore(nextCount: 0'u64, records: initTable[string, AccountDataRecord]())

proc accountDataKey(roomId, userId, eventType: string): string =
  roomId & "\0" & userId & "\0" & eventType

proc copyOrEmpty(node: JsonNode): JsonNode =
  if node.isNil:
    newJObject()
  else:
    node.copy()

proc isTombstoneEvent*(event: JsonNode): bool =
  event.isNil or event.kind != JObject or
    event{"content"}.isNil or
    (event{"content"}.kind == JObject and event{"content"}.len == 0)

proc update*(
  store: var AccountDataStore;
  roomId, userId, eventType: string;
  data: JsonNode;
): AccountDataResult =
  if data.isNil or data.kind != JObject or data{"type"}.isNil or data{"content"}.isNil:
    return (false, "Account data doesn't have all required fields.")

  inc store.nextCount
  let record = AccountDataRecord(
    roomId: roomId,
    userId: userId,
    eventType: eventType,
    streamPos: store.nextCount,
    event: data.copy(),
  )
  store.records[accountDataKey(roomId, userId, eventType)] = record
  (true, "")

proc updateContent*(
  store: var AccountDataStore;
  roomId, userId, eventType: string;
  content: JsonNode;
): AccountDataResult =
  store.update(
    roomId,
    userId,
    eventType,
    %*{
      "type": eventType,
      "content": copyOrEmpty(content),
    },
  )

proc delete*(
  store: var AccountDataStore;
  roomId, userId, eventType: string;
): AccountDataResult =
  store.update(
    roomId,
    userId,
    eventType,
    %*{
      "type": eventType,
      "content": {},
    },
  )

proc getRaw*(
  store: AccountDataStore;
  roomId, userId, eventType: string;
): AccountDataFetchResult =
  let key = accountDataKey(roomId, userId, eventType)
  if key notin store.records:
    return (false, newJObject(), "No account data found.")
  (true, store.records[key].event.copy(), "")

proc getContent*(
  store: AccountDataStore;
  roomId, userId, eventType: string;
  tombstoneIsMissing = false;
): AccountDataFetchResult =
  let raw = store.getRaw(roomId, userId, eventType)
  if not raw.ok:
    return raw
  if tombstoneIsMissing and isTombstoneEvent(raw.event):
    return (false, newJObject(), "No account data found.")
  (true, copyOrEmpty(raw.event{"content"}), "")

proc getGlobal*(
  store: AccountDataStore;
  userId, eventType: string;
  tombstoneIsMissing = false;
): AccountDataFetchResult =
  store.getContent("", userId, eventType, tombstoneIsMissing)

proc getRoom*(
  store: AccountDataStore;
  roomId, userId, eventType: string;
  tombstoneIsMissing = false;
): AccountDataFetchResult =
  store.getContent(roomId, userId, eventType, tombstoneIsMissing)

proc changesSince*(
  store: AccountDataStore;
  roomId, userId: string;
  since: uint64;
  upper = high(uint64);
): seq[JsonNode] =
  result = @[]
  var records: seq[AccountDataRecord] = @[]
  for _, record in store.records:
    if record.roomId == roomId and record.userId == userId and
        record.streamPos > since and record.streamPos <= upper:
      records.add(record)
  records.sort(proc(a, b: AccountDataRecord): int = cmp(a.streamPos, b.streamPos))
  for record in records:
    result.add(record.event.copy())

proc eraseUser*(
  store: var AccountDataStore;
  userId: string;
  roomId = "";
) =
  var doomed: seq[string] = @[]
  for key, record in store.records:
    if record.userId == userId and record.roomId == roomId:
      doomed.add(key)
  for key in doomed:
    store.records.del(key)

proc lastCount*(
  store: AccountDataStore;
  roomId, userId: string;
  upper = high(uint64);
): AccountDataCountResult =
  var best = 0'u64
  var found = false
  for _, record in store.records:
    if record.roomId == roomId and record.userId == userId and
        record.streamPos <= upper and (not found or record.streamPos > best):
      best = record.streamPos
      found = true
  if not found:
    return (false, 0'u64, "No account data found.")
  (true, best, "")

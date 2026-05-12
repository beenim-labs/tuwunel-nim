const
  RustPath* = "service/sending/data.rs"
  RustCrate* = "service"

import std/[algorithm, strutils, tables]

import service/sending/dest

type
  SendingEventKind* = enum
    sekPdu,
    sekEdu,
    sekFlush

  SendingEvent* = object
    kind*: SendingEventKind
    pduId*: string
    edu*: string

  QueueItem* = tuple[key: string, event: SendingEvent]
  OutgoingItem* = tuple[key: string, event: SendingEvent, dest: Destination]
  RequestItem* = tuple[event: SendingEvent, dest: Destination]
  ParseResult* = tuple[ok: bool, dest: Destination, event: SendingEvent, error: string]

  SendingData* = object
    queued*: OrderedTable[string, SendingEvent]
    active*: OrderedTable[string, SendingEvent]
    latestEduCount*: Table[string, uint64]
    nextEduCount*: uint64

proc pduEvent*(pduId: string): SendingEvent =
  SendingEvent(kind: sekPdu, pduId: pduId)

proc eduEvent*(serialized: string): SendingEvent =
  SendingEvent(kind: sekEdu, edu: serialized)

proc flushEvent*(): SendingEvent =
  SendingEvent(kind: sekFlush)

proc initSendingData*(): SendingData =
  SendingData(
    queued: initOrderedTable[string, SendingEvent](),
    active: initOrderedTable[string, SendingEvent](),
    latestEduCount: initTable[string, uint64](),
    nextEduCount: 0'u64,
  )

proc beU64(value: uint64): string =
  result = newString(8)
  for idx in 0 .. 7:
    result[idx] = char((value shr uint64((7 - idx) * 8)) and 0xFF'u64)

proc eventValue(event: SendingEvent): string =
  if event.kind == sekEdu:
    event.edu
  else:
    ""

proc eventFromStored(eventKey, value: string): SendingEvent =
  if value.len == 0:
    pduEvent(eventKey)
  else:
    eduEvent(value)

proc findSeparator(key: string; start = 0): int =
  for idx in start ..< key.len:
    if key[idx] == Separator:
      return idx
  -1

proc parseServerCurrentEvent*(key, value: string): ParseResult =
  if key.len == 0:
    return (false, Destination(), SendingEvent(), "empty sending key")

  if key[0] == '+':
    let sep = key.findSeparator(1)
    if sep < 0:
      return (false, Destination(), SendingEvent(), "missing appservice separator")
    let appserviceId = key[1 ..< sep]
    let eventKey = key[sep + 1 .. ^1]
    return (true, appserviceDestination(appserviceId), eventFromStored(eventKey, value), "")

  if key[0] == '$':
    let userSep = key.findSeparator(1)
    if userSep < 0:
      return (false, Destination(), SendingEvent(), "missing push user separator")
    let pushSep = key.findSeparator(userSep + 1)
    if pushSep < 0:
      return (false, Destination(), SendingEvent(), "missing pushkey separator")
    let userId = key[1 ..< userSep]
    let pushkey = key[userSep + 1 ..< pushSep]
    let eventKey = key[pushSep + 1 .. ^1]
    return (true, pushDestination(userId, pushkey), eventFromStored(eventKey, value), "")

  let serverSep = key.findSeparator()
  if serverSep < 0:
    return (false, Destination(), SendingEvent(), "missing federation separator")
  let serverName = key[0 ..< serverSep]
  let eventKey = key[serverSep + 1 .. ^1]
  (true, federationDestination(serverName), eventFromStored(eventKey, value), "")

proc queueRequests*(data: var SendingData; requests: openArray[RequestItem]): seq[string] =
  result = @[]
  for request in requests:
    if request.event.kind == sekFlush:
      result.add("")
      continue

    var key = request.dest.getPrefix()
    case request.event.kind
    of sekPdu:
      key.add(request.event.pduId)
    of sekEdu:
      inc data.nextEduCount
      key.add(beU64(data.nextEduCount))
    of sekFlush:
      discard

    data.queued[key] = request.event
    result.add(key)

proc deleteActiveRequest*(data: var SendingData; key: string) =
  data.active.del(key)

proc deleteAllActiveRequestsFor*(data: var SendingData; destination: Destination): int =
  let prefix = destination.getPrefix()
  var keys: seq[string] = @[]
  for key in data.active.keys:
    if key.startsWith(prefix):
      keys.add(key)
  for key in keys:
    data.active.del(key)
  keys.len

proc deleteAllRequestsFor*(data: var SendingData; destination: Destination): int =
  result = data.deleteAllActiveRequestsFor(destination)
  let prefix = destination.getPrefix()
  var keys: seq[string] = @[]
  for key in data.queued.keys:
    if key.startsWith(prefix):
      keys.add(key)
  for key in keys:
    data.queued.del(key)
  result += keys.len

proc markAsActive*(data: var SendingData; events: openArray[QueueItem]) =
  for item in events:
    if item.key.len == 0:
      continue
    data.active[item.key] = item.event
    data.queued.del(item.key)

proc sortedKeys(table: OrderedTable[string, SendingEvent]; prefix = ""): seq[string] =
  result = @[]
  for key in table.keys:
    if prefix.len == 0 or key.startsWith(prefix):
      result.add(key)
  result.sort(system.cmp[string])

proc activeRequests*(data: SendingData): seq[OutgoingItem] =
  result = @[]
  for key in sortedKeys(data.active):
    let parsed = parseServerCurrentEvent(key, eventValue(data.active[key]))
    if parsed.ok:
      result.add((key, data.active[key], parsed.dest))

proc activeRequestsFor*(data: SendingData; destination: Destination): seq[QueueItem] =
  result = @[]
  for key in sortedKeys(data.active, destination.getPrefix()):
    result.add((key, data.active[key]))

proc queuedRequests*(data: SendingData; destination: Destination; limit = high(int)): seq[QueueItem] =
  result = @[]
  for key in sortedKeys(data.queued, destination.getPrefix()):
    if result.len >= limit:
      break
    result.add((key, data.queued[key]))

proc setLatestEduCount*(data: var SendingData; serverName: string; lastCount: uint64) =
  data.latestEduCount[serverName] = lastCount

proc getLatestEduCount*(data: SendingData; serverName: string): uint64 =
  data.latestEduCount.getOrDefault(serverName, 0'u64)

const
  RustPath* = "service/presence/data.rs"
  RustCrate* = "service"

import std/[algorithm, json, tables]

import service/presence/aggregate
import service/presence/presence as presence_model

type
  PresenceRecord* = object
    userId*: string
    count*: uint64
    presence*: Presence

  PresenceFetchResult* = tuple[ok: bool, count: uint64, presence: Presence, err: string]
  PresenceSetResult* = tuple[ok: bool, stored: bool, count: uint64, err: string]

  PresenceData* = object
    nextCount*: uint64
    latest*: Table[string, PresenceRecord]

proc initPresenceData*(): PresenceData =
  PresenceData(nextCount: 0'u64, latest: initTable[string, PresenceRecord]())

proc saturatingSub(a, b: uint64): uint64 =
  if b > a: 0'u64 else: a - b

proc getPresenceRaw*(data: PresenceData; userId: string): PresenceFetchResult =
  if userId notin data.latest:
    return (false, 0'u64, Presence(), "Presence not found.")
  let record = data.latest[userId]
  (true, record.count, record.presence, "")

proc getPresence*(data: PresenceData; userId: string; nowMs: uint64): tuple[ok: bool, count: uint64, event: JsonNode, err: string] =
  let raw = data.getPresenceRaw(userId)
  if not raw.ok:
    return (false, 0'u64, newJObject(), raw.err)
  (true, raw.count, raw.presence.toPresenceEvent(userId, nowMs), "")

proc setPresence*(
  data: var PresenceData;
  userId: string;
  presenceState: string;
  currentlyActive = false;
  lastActiveAgo: uint64 = 0'u64;
  statusMsg = "";
  hasStatusMsg = false;
  nowMs: uint64;
): PresenceSetResult =
  let normalizedState = if presenceState.len == 0: PresenceOffline else: presenceState
  let lastPresence = data.getPresence(userId, nowMs)
  let stateChanged = not lastPresence.ok or
    lastPresence.event["content"]["presence"].getStr("") != normalizedState
  let oldStatus =
    if lastPresence.ok: lastPresence.event["content"]{"status_msg"}.getStr("") else: ""
  let newStatus = if hasStatusMsg: statusMsg else: ""
  let statusChanged = not lastPresence.ok or oldStatus != newStatus

  let lastLastActiveTs =
    if lastPresence.ok:
      saturatingSub(nowMs, uint64(max(lastPresence.event["content"]{"last_active_ago"}.getBiggestInt(0), 0)))
    else:
      0'u64
  let lastActiveTs = saturatingSub(nowMs, lastActiveAgo)

  if not statusChanged and not stateChanged and lastActiveTs < lastLastActiveTs:
    return (true, false, 0'u64, "")

  inc data.nextCount
  let cleanStatus = hasStatusMsg and statusMsg.len > 0
  let presence = presence_model.newPresence(
    normalizedState,
    currentlyActive,
    lastActiveTs,
    statusMsg,
    cleanStatus,
  )
  data.latest[userId] = PresenceRecord(userId: userId, count: data.nextCount, presence: presence)
  (true, true, data.nextCount, "")

proc removePresence*(data: var PresenceData; userId: string) =
  data.latest.del(userId)

proc presenceSince*(
  data: PresenceData;
  since: uint64;
  upper = high(uint64);
): seq[PresenceRecord] =
  result = @[]
  for _, record in data.latest:
    if record.count > since and record.count <= upper:
      result.add(record)
  result.sort(proc(a, b: PresenceRecord): int = cmp(a.count, b.count))

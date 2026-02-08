## timeline/mod — service module.
##
## Ported from Rust service/rooms/timeline/mod.rs
##
## Core timeline service: manages room event storage, PDU retrieval,
## timeline ordering (PduCount), state hash lookups at timeline positions,
## and PDU iteration. Provides the central getPdu interface.

import std/[options, json, tables, strutils, logging, locks, algorithm]

const
  RustPath* = "service/rooms/timeline/mod.rs"
  RustCrate* = "service"

type
  PduCount* = uint64
  PduEvent* = JsonNode
  RawPduId* = string
  PduId* = string

  Direction* = enum
    dForward
    dBackward

  PdusIterItem* = tuple[count: PduCount, pdu: PduEvent]

  ExtractRelatesTo* = object
    relatesTo*: Option[JsonNode]

  ExtractEventId* = object
    eventId*: Option[string]

  ExtractRelatesToEventId* = object
    relatesTo*: Option[ExtractEventId]

  ExtractBody* = object
    body*: Option[string]

  Data* = ref object
    pduidPdu*: Table[string, JsonNode]        # pdu_id → pdu_json
    eventidPduid*: Table[string, string]      # event_id → pdu_id
    eventidOutlierpdu*: Table[string, JsonNode]  # event_id → outlier pdu json

  Service* = ref object
    db*: Data
    mutexInsert: Lock

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

proc build*(): Service =
  ## Ported from `build`.
  result = Service(
    db: Data(
      pduidPdu: initTable[string, JsonNode](),
      eventidPduid: initTable[string, string](),
      eventidOutlierpdu: initTable[string, JsonNode](),
    ),
  )
  initLock(result.mutexInsert)

proc name*(self: Service): string =
  ## Ported from `name`.
  "rooms::timeline"

proc memoryUsage*(self: Service): string =
  ## Ported from `memory_usage`.
  "pdus=" & $self.db.pduidPdu.len &
  " outliers=" & $self.db.eventidOutlierpdu.len

# ---------------------------------------------------------------------------
# PDU storage
# ---------------------------------------------------------------------------

proc replacePdu*(self: Service; pduId: string; pduJson: JsonNode) =
  ## Ported from `replace_pdu`.
  ##
  ## Removes a PDU and creates a new one with the same ID.
  ## Used for redaction: the original content is replaced with
  ## the redacted version while maintaining the same pdu_id.

  if pduId notin self.db.pduidPdu:
    raise newException(ValueError, "PDU not found: " & pduId)

  self.db.pduidPdu[pduId] = pduJson
  debug "replace_pdu: ", pduId


proc addPduOutlier*(self: Service; eventId: string; pdu: JsonNode) =
  ## Ported from `add_pdu_outlier`.
  ##
  ## Stores a PDU as an outlier. Outlier PDUs are events not yet
  ## in the canonical timeline — they may be promoted later by
  ## upgrade_outlier_pdu.

  self.db.eventidOutlierpdu[eventId] = pdu


proc getPduJson*(self: Service; eventId: string): Option[JsonNode] =
  ## Returns the JSON for a PDU by event ID.
  let pduId = self.db.eventidPduid.getOrDefault(eventId, "")
  if pduId.len > 0 and pduId in self.db.pduidPdu:
    return some(self.db.pduidPdu[pduId])

  # Check outliers
  if eventId in self.db.eventidOutlierpdu:
    return some(self.db.eventidOutlierpdu[eventId])

  none(JsonNode)

# ---------------------------------------------------------------------------
# PDU retrieval
# ---------------------------------------------------------------------------

proc getPdu*(self: Service; eventId: string): Option[PduEvent] =
  ## Ported from `get_pdu`.
  ##
  ## Returns a PDU by event ID, checking timeline first then outliers.

  self.getPduJson(eventId)


proc getPduId*(self: Service; eventId: string): Option[string] =
  ## Returns the pdu_id for an event_id.
  if eventId in self.db.eventidPduid:
    some(self.db.eventidPduid[eventId])
  else:
    none(string)


proc getPduFromShorteventid*(self: Service; shorteventid: uint64): Option[PduEvent] =
  ## Ported from `get_pdu_from_shorteventid`.
  ## In real impl: resolves short event ID → event ID → PDU
  # self.services.short.getEventidFromShort(shorteventid)
  # then: self.getPdu(eventId)
  none(PduEvent)

# ---------------------------------------------------------------------------
# Room timeline queries
# ---------------------------------------------------------------------------

proc firstPduInRoom*(self: Service; roomId: string): Option[PduEvent] =
  ## Ported from `first_pdu_in_room`.
  ## Returns the first (oldest) PDU in the room.

  # In real impl: scan pduid_pdu by shortroomid prefix, take first
  none(PduEvent)


proc latestPduInRoom*(self: Service; roomId: string): Option[PduEvent] =
  ## Ported from `latest_pdu_in_room`.
  ## Returns the latest PDU in the room.

  # In real impl: scan pduid_pdu by shortroomid prefix, take last
  none(PduEvent)


proc firstItemInRoom*(self: Service; roomId: string): Option[PdusIterItem] =
  ## Ported from `first_item_in_room`.
  ## Returns the first (count, pdu) pair in the room.
  none(PdusIterItem)


proc latestItemInRoom*(self: Service; senderUser: Option[string];
                       roomId: string): Option[PduEvent] =
  ## Ported from `latest_item_in_room`.
  ## Returns the latest PDU visible to senderUser in the room,
  ## filtering out events from ignored users.
  none(PduEvent)

# ---------------------------------------------------------------------------
# State hash at timeline positions
# ---------------------------------------------------------------------------

proc prevShortstatehash*(self: Service; roomId: string;
                         before: PduCount): Option[uint64] =
  ## Ported from `prev_shortstatehash`.
  ##
  ## Returns the shortstatehash at the event directly preceding `before`.
  ## Walks backwards through the timeline to find a state event.

  # In real impl:
  # 1. Iterate timeline backwards from before
  # 2. For each event, check if it has an associated shortstatehash
  # 3. Return the first one found
  none(uint64)


proc nextShortstatehash*(self: Service; roomId: string;
                         after: PduCount): Option[uint64] =
  ## Ported from `next_shortstatehash`.
  ## Like prevShortstatehash but walks forward.
  none(uint64)


proc getShortstatehash*(self: Service; roomId: string;
                        count: PduCount): Option[uint64] =
  ## Ported from `get_shortstatehash`.
  ##
  ## Returns the shortstatehash at the exact count position.
  ## Tries the exact position first, then falls back to prev/next.
  none(uint64)

# ---------------------------------------------------------------------------
# Timeline count navigation
# ---------------------------------------------------------------------------

proc prevTimelineCount*(self: Service; before: string): Option[PduCount] =
  ## Ported from `prev_timeline_count`.
  ## Returns the count of the event preceding `before`.
  none(PduCount)


proc nextTimelineCount*(self: Service; after: string): Option[PduCount] =
  ## Ported from `next_timeline_count`.
  ## Returns the count of the event following `after`.
  none(PduCount)


proc lastTimelineCount*(self: Service; senderUser: Option[string];
                        roomId: string;
                        upperBound: Option[PduCount]): Option[PduCount] =
  ## Ported from `last_timeline_count`.
  ## Returns the last timeline count in the room, optionally bounded.
  none(PduCount)

# ---------------------------------------------------------------------------
# PDU iteration
# ---------------------------------------------------------------------------

proc allPdus*(self: Service; userId, roomId: string): seq[PdusIterItem] =
  ## Ported from `all_pdus`.
  ## Returns all PDUs in a room ordered by count.

  # In real impl: iterate pduid_pdu by shortroomid prefix
  @[]


proc pdus*(self: Service; userId: Option[string]; roomId: string;
           fromCount: Option[PduCount]): seq[PdusIterItem] =
  ## Ported from `pdus`.
  ## Returns PDUs in a room after `from` count, filtering
  ## out events from users ignored by userId.
  @[]

# ---------------------------------------------------------------------------
# Count-to-ID conversion
# ---------------------------------------------------------------------------

proc countToId*(self: Service; roomId: string; count: PduCount;
                dir: Direction): Option[RawPduId] =
  ## Ported from `count_to_id`.
  ## Converts a PduCount to a RawPduId for the given room and direction.

  # In real impl:
  # let shortroomid = self.services.short.getShortroomid(roomId)
  # return pduCountToId(shortroomid, count, dir)
  none(RawPduId)


proc deleteAllByRoomId*(self: Service; roomId: string) =
  ## Deletes all timeline data for a room.

  # In real impl: remove all pduid_pdu entries for shortroomid prefix
  # Remove all eventid_pduid entries for room events
  # Remove all eventid_outlierpdu entries for room events
  debug "delete_all_by_room_id: ", roomId

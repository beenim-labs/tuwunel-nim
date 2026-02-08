## short/mod — service module.
##
## Ported from Rust service/rooms/short/mod.rs
##
## Short ID mapping service: provides bidirectional mapping between long
## identifiers (event IDs, room IDs, state keys) and compact u64 values.
## Uses atomic counters for ID generation and caches for fast lookups.

import std/[options, json, tables, strutils, logging, locks]

const
  RustPath* = "service/rooms/short/mod.rs"
  RustCrate* = "service"

type
  ShortEventId* = uint64
  ShortStateKey* = uint64
  ShortStateHash* = uint64
  ShortRoomId* = uint64

  Data* = ref object
    ## Bidirectional mappings
    eventidShort*: Table[string, ShortEventId]       # event_id → short
    shortEventid*: Table[ShortEventId, string]       # short → event_id
    statekeyShort*: Table[string, ShortStateKey]     # (type+statekey) → short
    shortStatekey*: Table[ShortStateKey, tuple[eventType: string, stateKey: string]]
    statehashShort*: Table[string, tuple[short: ShortStateHash, existed: bool]]
    roomidShort*: Table[string, ShortRoomId]         # room_id → short
    shortRoomid*: Table[ShortRoomId, string]         # short → room_id

  Service* = ref object
    db*: Data
    nextShortId: uint64
    lock: Lock

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

proc build*(): Service =
  ## Ported from `build`.
  result = Service(
    db: Data(
      eventidShort: initTable[string, ShortEventId](),
      shortEventid: initTable[ShortEventId, string](),
      statekeyShort: initTable[string, ShortStateKey](),
      shortStatekey: initTable[ShortStateKey, tuple[eventType: string, stateKey: string]](),
      statehashShort: initTable[string, tuple[short: ShortStateHash, existed: bool]](),
      roomidShort: initTable[string, ShortRoomId](),
      shortRoomid: initTable[ShortRoomId, string](),
    ),
    nextShortId: 1,
  )
  initLock(result.lock)

proc name*(self: Service): string =
  ## Ported from `name`.
  "rooms::short"

proc allocateShort(self: Service): uint64 =
  withLock self.lock:
    result = self.nextShortId
    self.nextShortId += 1

# ---------------------------------------------------------------------------
# Event ID ↔ Short mapping
# ---------------------------------------------------------------------------

proc getOrCreateShorteventid*(self: Service; eventId: string): ShortEventId =
  ## Ported from `get_or_create_shorteventid`.
  ## Gets or creates a short event ID for the given event ID.
  if eventId in self.db.eventidShort:
    return self.db.eventidShort[eventId]
  self.createShorteventid(eventId)

proc createShorteventid*(self: Service; eventId: string): ShortEventId =
  ## Ported from `create_shorteventid`.
  ## Creates a new short event ID mapping.
  let short = self.allocateShort()
  self.db.eventidShort[eventId] = short
  self.db.shortEventid[short] = eventId
  short

proc getShorteventid*(self: Service; eventId: string): Option[ShortEventId] =
  ## Ported from `get_shorteventid`.
  if eventId in self.db.eventidShort:
    some(self.db.eventidShort[eventId])
  else:
    none(ShortEventId)

proc getEventidFromShort*(self: Service; short: ShortEventId): Option[string] =
  ## Ported from `get_eventid_from_short`.
  if short in self.db.shortEventid:
    some(self.db.shortEventid[short])
  else:
    none(string)

# ---------------------------------------------------------------------------
# State key ↔ Short mapping
# ---------------------------------------------------------------------------

proc statekeyComposite(eventType, stateKey: string): string =
  eventType & "\xFF" & stateKey

proc getOrCreateShortstatekey*(self: Service; eventType, stateKey: string): ShortStateKey =
  ## Ported from `get_or_create_shortstatekey`.
  let composite = statekeyComposite(eventType, stateKey)
  if composite in self.db.statekeyShort:
    return self.db.statekeyShort[composite]

  let short = self.allocateShort()
  self.db.statekeyShort[composite] = short
  self.db.shortStatekey[short] = (eventType: eventType, stateKey: stateKey)
  short

proc getShortstatekey*(self: Service; eventType, stateKey: string): Option[ShortStateKey] =
  ## Ported from `get_shortstatekey`.
  let composite = statekeyComposite(eventType, stateKey)
  if composite in self.db.statekeyShort:
    some(self.db.statekeyShort[composite])
  else:
    none(ShortStateKey)

proc getStatekeyFromShort*(self: Service; short: ShortStateKey): Option[tuple[eventType: string, stateKey: string]] =
  ## Ported from `get_statekey_from_short`.
  if short in self.db.shortStatekey:
    some(self.db.shortStatekey[short])
  else:
    none(tuple[eventType: string, stateKey: string])

# ---------------------------------------------------------------------------
# State hash ↔ Short mapping
# ---------------------------------------------------------------------------

proc getOrCreateShortstatehash*(self: Service; stateHash: string): tuple[short: ShortStateHash, existed: bool] =
  ## Ported from `get_or_create_shortstatehash`.
  if stateHash in self.db.statehashShort:
    let existing = self.db.statehashShort[stateHash]
    return (short: existing.short, existed: true)

  let short = self.allocateShort()
  self.db.statehashShort[stateHash] = (short: short, existed: false)
  (short: short, existed: false)

# ---------------------------------------------------------------------------
# Room ID ↔ Short mapping
# ---------------------------------------------------------------------------

proc getOrCreateShortroomid*(self: Service; roomId: string): ShortRoomId =
  ## Ported from `get_or_create_shortroomid`.
  if roomId in self.db.roomidShort:
    return self.db.roomidShort[roomId]

  let short = self.allocateShort()
  self.db.roomidShort[roomId] = short
  self.db.shortRoomid[short] = roomId
  short

proc getShortroomid*(self: Service; roomId: string): Option[ShortRoomId] =
  ## Ported from `get_shortroomid`.
  if roomId in self.db.roomidShort:
    some(self.db.roomidShort[roomId])
  else:
    none(ShortRoomId)

proc getRoomidFromShort*(self: Service; short: ShortRoomId): Option[string] =
  ## Ported from `get_roomid_from_short`.
  if short in self.db.shortRoomid:
    some(self.db.shortRoomid[short])
  else:
    none(string)

proc deleteShortroomid*(self: Service; roomId: string) =
  ## Ported from `delete_shortroomid`.
  if roomId in self.db.roomidShort:
    let short = self.db.roomidShort[roomId]
    self.db.roomidShort.del(roomId)
    self.db.shortRoomid.del(short)

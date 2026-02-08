## state/mod — service module.
##
## Ported from Rust service/rooms/state/mod.rs
##
## Room state management: associates state hashes with events, manages
## forward extremities, handles state forcing (for backfill/import),
## computes auth events, and tracks room versions.

import std/[options, json, tables, strutils, logging, sets, locks]

const
  RustPath* = "service/rooms/state/mod.rs"
  RustCrate* = "service"

type
  ShortStateHash* = uint64
  ShortEventId* = uint64

  Data* = ref object
    roomidShortstatehash*: Table[string, ShortStateHash]
    eventidShortstatehash*: Table[string, ShortStateHash]
    shorteventidShortstatehash*: Table[ShortEventId, ShortStateHash]
    roomidForwardExtremities*: Table[string, seq[string]]  # room_id → event_ids

  Service* = ref object
    db*: Data
    mutex: Lock  # Room mutex map

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

proc newData(): Data =
  Data(
    roomidShortstatehash: initTable[string, ShortStateHash](),
    eventidShortstatehash: initTable[string, ShortStateHash](),
    shorteventidShortstatehash: initTable[ShortEventId, ShortStateHash](),
    roomidForwardExtremities: initTable[string, seq[string]](),
  )

proc build*(): Service =
  ## Ported from `build`.
  result = Service(db: newData())
  initLock(result.mutex)

proc name*(self: Service): string =
  ## Ported from `name`.
  "rooms::state"

proc memoryUsage*(self: Service): string =
  ## Ported from `memory_usage`.
  "shortstatehash=" & $self.db.roomidShortstatehash.len &
  " extremities=" & $self.db.roomidForwardExtremities.len

# ---------------------------------------------------------------------------
# State hash management
# ---------------------------------------------------------------------------

proc forceState*(self: Service; roomId: string; shortstatehash: ShortStateHash;
                 statediffnew: seq[tuple[key: uint64, event: uint64]];
                 statediffremoved: seq[tuple[key: uint64, event: uint64]]) =
  ## Ported from `force_state`.
  ##
  ## Sets the room to the given statehash. Used for state resets and backfill.
  ## Updates server tracking and membership caches based on new state diff.

  self.db.roomidShortstatehash[roomId] = shortstatehash

  # Process new state events to update membership/server caches
  for (shortstatekey, shorteventid) in statediffnew:
    # In real impl: resolve shortstatekey to (event_type, state_key)
    # If event_type == "m.room.member":
    #   parse content, update membership
    # Update server participation tracking
    discard

  debug "force_state: room ", roomId, " → state ", shortstatehash


proc setEventState*(self: Service; eventId, roomId: string;
                    stateIdsCompressed: seq[tuple[key: uint64, event: uint64]]): ShortStateHash =
  ## Ported from `set_event_state`.
  ##
  ## Generates a new StateHash and associates it with the incoming event.
  ## This adds all current state events to stateid_pduid and adds
  ## the incoming event to eventid_statehash.

  # In real impl:
  # 1. Compute state hash from compressed state
  # 2. Get or create shortstatehash
  # 3. Save state diff
  # 4. Associate event with state

  var hashValue: ShortStateHash = 0
  for (k, v) in stateIdsCompressed:
    hashValue = hashValue xor (k * 2654435761'u64) xor v

  # In real impl: self.services.short.getOrCreateShortstatehash(stateHash)
  self.db.eventidShortstatehash[eventId] = hashValue
  hashValue


proc appendToState*(self: Service; newPdu: JsonNode): ShortStateHash =
  ## Ported from `append_to_state`.
  ##
  ## Adds a state event to the current room state and returns the new
  ## short state hash.

  let roomId = newPdu.getOrDefault("room_id").getStr("")
  let eventId = newPdu.getOrDefault("event_id").getStr("")

  # In real impl:
  # 1. Get current room shortstatehash
  # 2. Load current compressed state
  # 3. Add new event's shortstatekey → shorteventid
  # 4. Compute new state hash
  # 5. Save state diff
  # 6. Associate event with new state

  let currentHash = self.getRoomShortstatehash(roomId)
  let newHash = currentHash + 1  # placeholder
  self.db.eventidShortstatehash[eventId] = newHash
  newHash


proc setRoomState*(self: Service; roomId: string; shortstatehash: ShortStateHash) =
  ## Ported from `set_room_state`.
  ## Sets the state hash without updating caches. Used internally.
  self.db.roomidShortstatehash[roomId] = shortstatehash


proc getAuthEvents*(self: Service; roomId: string; kind: string;
                    sender: string; stateKey: Option[string];
                    content: JsonNode): seq[JsonNode] =
  ## Ported from `get_auth_events`.
  ##
  ## Fetches auth events from the current state for event authorization.
  ## Returns the auth events needed based on the event type:
  ## - Always: m.room.create, m.room.power_levels, sender's m.room.member
  ## - For m.room.member: target user's m.room.member, m.room.join_rules,
  ##   m.room.third_party_invite (if applicable)

  var authEvents: seq[JsonNode] = @[]

  # In real impl: fetch from current state based on auth rules
  # 1. Always fetch m.room.create("")
  # 2. Always fetch m.room.power_levels("")
  # 3. Always fetch m.room.member(sender)
  # 4. If kind == "m.room.member":
  #      fetch m.room.member(state_key)
  #      fetch m.room.join_rules("")
  #      maybe fetch m.room.third_party_invite

  debug "get_auth_events: room=", roomId, " kind=", kind, " sender=", sender
  authEvents

# ---------------------------------------------------------------------------
# Room version
# ---------------------------------------------------------------------------

proc getRoomVersionRules*(self: Service; roomId: string): string =
  ## Ported from `get_room_version_rules`.
  ## Returns the authorization rules for the room's version.
  let version = self.getRoomVersion(roomId)
  # In real impl: look up RoomVersionRules for version
  version


proc getRoomVersion*(self: Service; roomId: string): string =
  ## Ported from `get_room_version`.
  ##
  ## Returns the room's version by looking at the m.room.create event.

  # In real impl:
  # let createEvent = self.services.stateAccessor.roomStateGet(roomId, "m.room.create", "")
  # return createEvent.content.room_version or default "1"
  "10"  # placeholder default

# ---------------------------------------------------------------------------
# State hash lookups
# ---------------------------------------------------------------------------

proc getRoomShortstatehash*(self: Service; roomId: string): ShortStateHash =
  ## Ported from `get_room_shortstatehash`.
  self.db.roomidShortstatehash.getOrDefault(roomId, 0)

proc pduShortstatehash*(self: Service; eventId: string): Option[ShortStateHash] =
  ## Ported from `pdu_shortstatehash`.
  if eventId in self.db.eventidShortstatehash:
    some(self.db.eventidShortstatehash[eventId])
  else:
    none(ShortStateHash)

proc getShortstatehash*(self: Service; shorteventid: ShortEventId): Option[ShortStateHash] =
  ## Ported from `get_shortstatehash`.
  if shorteventid in self.db.shorteventidShortstatehash:
    some(self.db.shorteventidShortstatehash[shorteventid])
  else:
    none(ShortStateHash)

proc deleteRoomShortstatehash*(self: Service; roomId: string) =
  ## Ported from `delete_room_shortstatehash`.
  self.db.roomidShortstatehash.del(roomId)

# ---------------------------------------------------------------------------
# Forward extremities
# ---------------------------------------------------------------------------

proc getForwardExtremities*(self: Service; roomId: string): seq[string] =
  ## Ported from `get_forward_extremities`.
  self.db.roomidForwardExtremities.getOrDefault(roomId, @[])

proc setForwardExtremities*(self: Service; roomId: string; eventIds: seq[string]) =
  ## Ported from `set_forward_extremities`.
  self.db.roomidForwardExtremities[roomId] = eventIds

proc deleteAllRoomsForwardExtremities*(self: Service; roomId: string) =
  ## Ported from `delete_all_rooms_forward_extremities`.
  self.db.roomidForwardExtremities.del(roomId)

# ---------------------------------------------------------------------------
# Stripped state summary
# ---------------------------------------------------------------------------

proc summaryStripped*(self: Service; event: JsonNode): seq[JsonNode] =
  ## Ported from `summary_stripped`.
  ## Creates a stripped state event summary for invites/knocks.
  let eventType = event.getOrDefault("type").getStr("")
  let stateKey = event.getOrDefault("state_key").getStr("")
  let sender = event.getOrDefault("sender").getStr("")
  let content = event.getOrDefault("content")

  @[%*{
    "type": eventType,
    "state_key": stateKey,
    "sender": sender,
    "content": content,
  }]

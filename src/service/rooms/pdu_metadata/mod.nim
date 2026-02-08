## pdu_metadata/mod — service module.
##
## Ported from Rust service/rooms/pdu_metadata/mod.rs
##
## PDU metadata management: tracks event relations (replies, reactions,
## threads), soft-fail status for federation, and reference marking
## for extremity calculation.

import std/[options, json, tables, strutils, logging, sets]

const
  RustPath* = "service/rooms/pdu_metadata/mod.rs"
  RustCrate* = "service"

type
  PduCount* = uint64

  Data* = ref object
    ## tofrom_relation: maps (to_event, from_event) for event relationships
    tofromRelation*: Table[string, seq[string]]   # to_event → [from_events]
    ## Referenced events (used for forward extremity calculation)
    referencedEvents*: Table[string, HashSet[string]]  # room_id → {event_ids}
    ## Soft-failed event tracking
    softFailedEvents*: HashSet[string]

  Service* = ref object
    db*: Data

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

proc build*(): Service =
  ## Ported from `build`.
  Service(
    db: Data(
      tofromRelation: initTable[string, seq[string]](),
      referencedEvents: initTable[string, HashSet[string]](),
      softFailedEvents: initHashSet[string](),
    ),
  )

proc name*(self: Service): string =
  ## Ported from `name`.
  "rooms::pdu_metadata"

# ---------------------------------------------------------------------------
# Relations
# ---------------------------------------------------------------------------

proc addRelation*(self: Service; fromCount: PduCount; toEvent: string) =
  ## Ported from `add_relation`.
  ##
  ## Records a relation between two events (reply, reaction, thread, etc.).
  ## `fromCount` is the PDU count of the relating event,
  ## `toEvent` is the event being related to.

  if toEvent notin self.db.tofromRelation:
    self.db.tofromRelation[toEvent] = @[]
  self.db.tofromRelation[toEvent].add($fromCount)

  debug "add_relation: ", fromCount, " → ", toEvent


proc getRelations*(self: Service; toEvent: string): seq[string] =
  ## Gets all events related to the given event.
  self.db.tofromRelation.getOrDefault(toEvent, @[])

# ---------------------------------------------------------------------------
# Reference tracking (for extremity calculation)
# ---------------------------------------------------------------------------

proc markEventReferenced*(self: Service; roomId: string; eventId: string) =
  ## Marks an event as referenced (no longer an extremity candidate).
  if roomId notin self.db.referencedEvents:
    self.db.referencedEvents[roomId] = initHashSet[string]()
  self.db.referencedEvents[roomId].incl(eventId)

proc isEventReferenced*(self: Service; roomId, eventId: string): bool =
  ## Ported from `is_event_referenced`.
  ## Checks if an event is referenced by another event in the room.
  if roomId in self.db.referencedEvents:
    return eventId in self.db.referencedEvents[roomId]
  false

# ---------------------------------------------------------------------------
# Soft-fail tracking
# ---------------------------------------------------------------------------

proc markEventSoftFailed*(self: Service; eventId: string) =
  ## Ported from `mark_event_soft_failed`.
  ##
  ## Marks an event as soft-failed. Soft-failed events pass auth
  ## checks but fail against the forward extremities state. They
  ## are stored but not appended to the timeline.
  self.db.softFailedEvents.incl(eventId)
  debug "mark_event_soft_failed: ", eventId

proc isEventSoftFailed*(self: Service; eventId: string): bool =
  ## Ported from `is_event_soft_failed`.
  eventId in self.db.softFailedEvents

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

proc deleteAllReferencedForRoom*(self: Service; roomId: string) =
  ## Ported from `delete_all_referenced_for_room`.
  self.db.referencedEvents.del(roomId)
  debug "delete_all_referenced_for_room: ", roomId

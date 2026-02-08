## event_handler/mod — service module.
##
## Ported from Rust service/rooms/event_handler/mod.rs
##
## Provides the EventHandler service for processing incoming PDUs from
## federation. Manages back-off tracking for unreachable/invalid events
## and provides event existence/fetch primitives used by sub-modules.

import std/[options, json, tables, strutils, locks, times, hashes]

const
  RustPath* = "service/rooms/event_handler/mod.rs"
  RustCrate* = "service"

type
  RateLimitState* = tuple
    lastFailed: Time
    failCount: uint32

  RoomMutexMap* = ref object
    ## Lightweight mutex-map keyed by room ID.
    locks*: Table[string, Lock]

  Service* = ref object
    mutexFederation*: RoomMutexMap
    badEventRatelimiter*: Table[string, RateLimitState]
    ratelimiterLock: Lock

# ---------------------------------------------------------------------------
# RoomMutexMap helpers
# ---------------------------------------------------------------------------

proc newRoomMutexMap*(): RoomMutexMap =
  RoomMutexMap(locks: initTable[string, Lock]())

proc len*(m: RoomMutexMap): int =
  m.locks.len

# ---------------------------------------------------------------------------
# Service construction
# ---------------------------------------------------------------------------

proc build*(): Service =
  ## Ported from `build`.
  result = Service(
    mutexFederation: newRoomMutexMap(),
    badEventRatelimiter: initTable[string, RateLimitState](),
  )
  initLock(result.ratelimiterLock)

proc name*(self: Service): string =
  ## Ported from `name`.
  "rooms::event_handler"

# ---------------------------------------------------------------------------
# Memory / cache
# ---------------------------------------------------------------------------

proc memoryUsage*(self: Service): string =
  ## Ported from `memory_usage`.
  var out = ""
  let mutexCount = self.mutexFederation.len
  out.add("federation_mutex: " & $mutexCount & "\n")

  withLock self.ratelimiterLock:
    let berCount = self.badEventRatelimiter.len
    out.add("bad_event_ratelimiter: " & $berCount & "\n")

  out

proc clearCache*(self: Service) =
  ## Ported from `clear_cache`.
  withLock self.ratelimiterLock:
    self.badEventRatelimiter.clear()

# ---------------------------------------------------------------------------
# Back-off tracking
# ---------------------------------------------------------------------------

proc backOff*(self: Service; eventId: string) =
  ## Ported from `back_off`.
  ## Records or increments failed-attempt tracking for an event.
  withLock self.ratelimiterLock:
    if eventId in self.badEventRatelimiter:
      var entry = self.badEventRatelimiter[eventId]
      entry.lastFailed = getTime()
      if entry.failCount < high(uint32):
        entry.failCount += 1
      self.badEventRatelimiter[eventId] = entry
    else:
      self.badEventRatelimiter[eventId] = (lastFailed: getTime(), failCount: 1'u32)

proc continueExponentialBackoff(minDur, maxDur, elapsed: Duration; tries: uint32): bool =
  ## Returns true if we should still be backing off (i.e. not enough time
  ## has passed relative to the exponential backoff for `tries`).
  let base = minDur.inSeconds
  let maxSecs = maxDur.inSeconds
  # Exponential: base * 2^(tries-1), capped at maxSecs
  var delaySecs = base
  for i in 1 ..< tries.int:
    delaySecs = delaySecs * 2
    if delaySecs >= maxSecs:
      delaySecs = maxSecs
      break
  elapsed.inSeconds < delaySecs

proc isBackedOff*(self: Service; eventId: string;
                  minBackoff, maxBackoff: Duration): bool =
  ## Ported from `is_backed_off`.
  ## Returns true if the event is currently in back-off.
  withLock self.ratelimiterLock:
    if eventId notin self.badEventRatelimiter:
      return false
    let (lastTime, tries) = self.badEventRatelimiter[eventId]
    let elapsed = getTime() - lastTime
    return continueExponentialBackoff(minBackoff, maxBackoff, elapsed, tries)

# ---------------------------------------------------------------------------
# Event existence / fetch primitives
# ---------------------------------------------------------------------------

proc eventExists*(self: Service; eventId: string): bool =
  ## Ported from `event_exists`.
  ## Checks if the event exists in the timeline (delegates to timeline service).
  # In the full implementation this would call:
  #   self.services.timeline.pduExists(eventId)
  false

proc eventFetch*(self: Service; eventId: string): Option[JsonNode] =
  ## Ported from `event_fetch`.
  ## Fetches a PDU from the timeline (delegates to timeline service).
  # In the full implementation this would call:
  #   self.services.timeline.getPdu(eventId)
  none(JsonNode)

# ---------------------------------------------------------------------------
# Room-ID consistency check
# ---------------------------------------------------------------------------

proc checkRoomId*(roomId: string; pduRoomId: string; pduEventId: string) =
  ## Ported from `check_room_id`.
  ## Verifies the PDU belongs to the expected room.
  if pduRoomId != roomId:
    raise newException(ValueError,
      "Found event " & pduEventId & " from room " & pduRoomId &
      " in room " & roomId)

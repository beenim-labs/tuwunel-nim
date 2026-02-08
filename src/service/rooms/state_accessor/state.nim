## state_accessor/state — service module.
##
## Ported from Rust service/rooms/state_accessor/state.rs
##
## Low-level state accessor functions that operate on short-state-hash values.
## Handles membership lookups at historical state points, state event
## containment checks, individual and bulk state retrieval, and
## state diff computation (added/removed events between two states).

import std/[options, json, tables, strutils, logging, sequtils]

const
  RustPath* = "service/rooms/state_accessor/state.rs"
  RustCrate* = "service"

type
  ShortStateHash* = uint64
  ShortStateKey* = uint64
  ShortEventId* = uint64
  CompressedStateEvent* = tuple[shortstatekey: ShortStateKey, shorteventid: ShortEventId]
  CompressedState* = seq[CompressedStateEvent]

# ---------------------------------------------------------------------------
# Membership checks at a historical state point
# ---------------------------------------------------------------------------

proc userWasJoined*(self: Service; shortstatehash: ShortStateHash;
                    userId: string): bool =
  ## Ported from `user_was_joined`.
  ## Checks if the user was a joined member at a given historical state.

  # In real impl: look up member state at shortstatehash
  # self.stateGetContent(shortstatehash, "m.room.member", userId)
  # check if membership == "join"
  let membership = self.userMembershipAt(shortstatehash, userId)
  membership == "join"


proc userWasInvited*(self: Service; shortstatehash: ShortStateHash;
                     userId: string): bool =
  ## Ported from `user_was_invited`.
  ## Checks if the user was invited or joined at a given historical state.

  let membership = self.userMembershipAt(shortstatehash, userId)
  membership == "join" or membership == "invite"


proc userMembershipAt*(self: Service; shortstatehash: ShortStateHash;
                       userId: string): string =
  ## Ported from `user_membership`.
  ## Returns the membership state for a user at a given state hash.

  # In real impl: self.stateGetContent(shortstatehash, "m.room.member", userId)
  #   then extract membership field
  # For now delegate to state_get
  let event = self.stateGet(shortstatehash, "m.room.member", userId)
  if event.isSome:
    let content = event.get().getOrDefault("content")
    if content.kind == JObject:
      return content.getOrDefault("membership").getStr("")
  ""

# ---------------------------------------------------------------------------
# State content/containment lookups
# ---------------------------------------------------------------------------

proc stateGetContent*(self: Service; shortstatehash: ShortStateHash;
                      eventType: string; stateKey: string): Option[JsonNode] =
  ## Ported from `state_get_content`.
  ## Returns the deserialized content of a state event at a given state hash.
  let event = self.stateGet(shortstatehash, eventType, stateKey)
  if event.isSome:
    let content = event.get().getOrDefault("content")
    if content.kind != JNull:
      return some(content)
  none(JsonNode)


proc stateContains*(self: Service; shortstatehash: ShortStateHash;
                    eventType: string; stateKey: string): bool =
  ## Ported from `state_contains`.
  ## Checks if a specific (event_type, state_key) exists in the state.

  # In real impl: get shortstatekey then check compressed state
  # self.services.short.getShortstatekey(eventType, stateKey)
  # then check if shortstatekey is in the compressed state at shortstatehash
  let event = self.stateGet(shortstatehash, eventType, stateKey)
  event.isSome


proc stateContainsType*(self: Service; shortstatehash: ShortStateHash;
                        eventType: string): bool =
  ## Ported from `state_contains_type`.
  ## Checks if any event of the given type exists in the state.

  # In real impl: iterate compressed state and check shortstatekeys
  # matching the event type
  let pdus = self.stateTypePdus(shortstatehash, eventType)
  pdus.len > 0


proc stateContainsShortstatekey*(self: Service; shortstatehash: ShortStateHash;
                                  shortstatekey: ShortStateKey): bool =
  ## Ported from `state_contains_shortstatekey`.
  ## Checks if a specific shortstatekey exists in the compressed state.

  # In real impl: load compressed state and check for shortstatekey
  let state = self.loadFullState(shortstatehash)
  for (ssk, _) in state:
    if ssk == shortstatekey:
      return true
  false

# ---------------------------------------------------------------------------
# Single state event retrieval
# ---------------------------------------------------------------------------

proc stateGet*(self: Service; shortstatehash: ShortStateHash;
               eventType: string; stateKey: string): Option[JsonNode] =
  ## Ported from `state_get`.
  ## Returns a single PDU from the state by (event_type, state_key).

  # In real impl:
  #   shortstatekey = self.services.short.getShortstatekey(eventType, stateKey)
  #   shorteventid = look up in compressed state
  #   eventId = self.services.short.getEventidFromShort(shorteventid)
  #   return self.services.timeline.getPdu(eventId)
  none(JsonNode)  # placeholder


proc stateGetId*(self: Service; shortstatehash: ShortStateHash;
                 eventType: string; stateKey: string): Option[string] =
  ## Ported from `state_get_id`.
  ## Returns the event ID of a state event.

  # In real impl: similar to stateGet but returns event ID instead of full PDU
  none(string)  # placeholder


proc stateGetShortid*(self: Service; shortstatehash: ShortStateHash;
                      eventType: string; stateKey: string): Option[ShortEventId] =
  ## Ported from `state_get_shortid`.
  ## Returns the short event ID of a state event.

  # In real impl:
  #   shortstatekey = self.services.short.getShortstatekey(eventType, stateKey)
  #   load compressed state at shortstatehash
  #   binary search for shortstatekey
  #   return shorteventid
  none(ShortEventId)  # placeholder

# ---------------------------------------------------------------------------
# State enumeration
# ---------------------------------------------------------------------------

proc stateTypePdus*(self: Service; shortstatehash: ShortStateHash;
                    eventType: string): seq[JsonNode] =
  ## Ported from `state_type_pdus`.
  ## Returns all PDUs of a given event type from the state.

  # In real impl: iterate compressed state, filter by event type shortstatekey prefix
  @[]  # placeholder


proc stateKeysWithIds*(self: Service; shortstatehash: ShortStateHash;
                       eventType: string): seq[tuple[stateKey: string, eventId: string]] =
  ## Ported from `state_keys_with_ids`.
  ## Returns state_keys with their event IDs for a given event type.

  # In real impl: get short type key prefix, iterate compressed state,
  # resolve each shortstatekey back to (type, state_key) pair
  @[]  # placeholder


proc stateKeysWithShortids*(self: Service; shortstatehash: ShortStateHash;
                            eventType: string): seq[tuple[stateKey: string, shortEventId: ShortEventId]] =
  ## Ported from `state_keys_with_shortids`.
  ## Like stateKeysWithIds but returns short event IDs.

  # In real impl: same as above but skip the event ID resolution
  @[]  # placeholder


proc stateKeys*(self: Service; shortstatehash: ShortStateHash;
                eventType: string): seq[string] =
  ## Ported from `state_keys`.
  ## Returns just the state_keys for a given event type.

  # In real impl: iterate compressed state matching event type, resolve keys
  @[]  # placeholder

# ---------------------------------------------------------------------------
# State diffs
# ---------------------------------------------------------------------------

proc stateRemoved*(self: Service; hashA, hashB: ShortStateHash):
    seq[tuple[key: ShortStateKey, eventId: ShortEventId]] =
  ## Ported from `state_removed`.
  ## Returns state events present in hashA but not in hashB (removals).

  let stateA = self.loadFullState(hashA)
  let stateB = self.loadFullState(hashB)
  let setBKeys = block:
    var s: seq[ShortStateKey] = @[]
    for (k, _) in stateB: s.add(k)
    s

  for (key, eid) in stateA:
    if key notin setBKeys:
      result.add((key: key, eventId: eid))


proc stateAdded*(self: Service; hashA, hashB: ShortStateHash):
    seq[tuple[key: ShortStateKey, eventId: ShortEventId]] =
  ## Ported from `state_added`.
  ## Returns state events present in hashB but not in hashA (additions).

  let stateA = self.loadFullState(hashA)
  let stateB = self.loadFullState(hashB)
  let setAKeys = block:
    var s: seq[ShortStateKey] = @[]
    for (k, _) in stateA: s.add(k)
    s

  for (key, eid) in stateB:
    if key notin setAKeys:
      result.add((key: key, eventId: eid))

# ---------------------------------------------------------------------------
# Full state retrieval
# ---------------------------------------------------------------------------

proc stateFull*(self: Service; shortstatehash: ShortStateHash):
    seq[tuple[eventType: string, stateKey: string, event: JsonNode]] =
  ## Ported from `state_full`.
  ## Returns the full state as (event_type, state_key, event) tuples.

  # In real impl: load compressed state, resolve each shortstatekey
  # back to (type, state_key), fetch each PDU
  @[]  # placeholder


proc stateFullPdus*(self: Service; shortstatehash: ShortStateHash): seq[JsonNode] =
  ## Ported from `state_full_pdus`.
  ## Returns all PDUs in the full state.

  # In real impl: load compressed state, resolve event IDs, fetch PDUs
  @[]  # placeholder


proc stateFullIds*(self: Service; shortstatehash: ShortStateHash):
    seq[tuple[key: ShortStateKey, eventId: string]] =
  ## Ported from `state_full_ids`.
  ## Returns the full state as (shortstatekey, event_id) pairs.

  # In real impl: load compressed state, resolve each short event ID
  # to full event ID via self.services.short.getEventidFromShort
  @[]  # placeholder


proc stateFullShortids*(self: Service; shortstatehash: ShortStateHash): CompressedState =
  ## Ported from `state_full_shortids`.
  ## Returns the full state as compressed (shortstatekey, shorteventid) pairs.

  # In real impl: self.services.stateCompressor.loadShortStateHash(shortstatehash)
  #   then parse each compressed state event
  @[]  # placeholder


proc loadFullState*(self: Service; shortstatehash: ShortStateHash): CompressedState =
  ## Ported from `load_full_state`.
  ## Loads the complete compressed state for a given state hash.

  # In real impl: self.services.stateCompressor.loadShortStateHash(shortstatehash)
  #   collect into Vec<CompressedStateEvent>
  @[]  # placeholder

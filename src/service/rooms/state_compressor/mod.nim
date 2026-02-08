## state_compressor/mod — service module.
##
## Ported from Rust service/rooms/state_compressor/mod.rs
##
## State compression: efficient storage of room state using delta encoding.
## Stores state as diffs (added/removed) relative to parent states rather
## than full copies. Uses an LRU cache for performance.

import std/[options, json, tables, strutils, logging, locks, sets]

const
  RustPath* = "service/rooms/state_compressor/mod.rs"
  RustCrate* = "service"
  CompressedStateEventSize* = 16  # 2 * sizeof(uint64)

type
  ShortStateHash* = uint64
  ShortStateKey* = uint64
  ShortEventId* = uint64
  CompressedStateEvent* = tuple[shortstatekey: ShortStateKey, shorteventid: ShortEventId]
  CompressedState* = seq[CompressedStateEvent]

  StateDiff* = object
    parent*: Option[ShortStateHash]
    added*: CompressedState
    removed*: CompressedState

  ShortStateInfo* = object
    shortstatehash*: ShortStateHash
    fullState*: CompressedState
    added*: CompressedState
    removed*: CompressedState

  # LRU cache for state info chains
  StateInfoCache = Table[ShortStateHash, seq[ShortStateInfo]]

  Service* = ref object
    stateinfoCache*: StateInfoCache
    cacheLock: Lock
    db*: Table[ShortStateHash, StateDiff]  # shortstatehash → diff

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

proc build*(): Service =
  ## Ported from `build`.
  result = Service(
    stateinfoCache: initTable[ShortStateHash, seq[ShortStateInfo]](),
    db: initTable[ShortStateHash, StateDiff](),
  )
  initLock(result.cacheLock)

proc name*(self: Service): string =
  ## Ported from `name`.
  "rooms::state_compressor"

proc memoryUsage*(self: Service): string =
  ## Ported from `memory_usage`.
  withLock self.cacheLock:
    "cache=" & $self.stateinfoCache.len

proc clearCache*(self: Service) =
  ## Ported from `clear_cache`.
  withLock self.cacheLock:
    self.stateinfoCache.clear()

# ---------------------------------------------------------------------------
# Compressed state event encoding
# ---------------------------------------------------------------------------

proc compressStateEvent*(shortstatekey: ShortStateKey;
                         shorteventid: ShortEventId): CompressedStateEvent =
  ## Ported from `compress_state_event` (free function).
  ## Creates a compressed state event from its components.
  (shortstatekey: shortstatekey, shorteventid: shorteventid)

proc parseCompressedStateEvent*(compressed: CompressedStateEvent):
    tuple[shortstatekey: ShortStateKey, shorteventid: ShortEventId] =
  ## Ported from `parse_compressed_state_event`.
  ## Extracts components from a compressed state event.
  (shortstatekey: compressed.shortstatekey, shorteventid: compressed.shorteventid)

proc compressedStateSize*(state: CompressedState): int =
  ## Ported from `compressed_state_size`.
  ## Returns the byte size of a compressed state.
  state.len * CompressedStateEventSize

# ---------------------------------------------------------------------------
# State loading and caching
# ---------------------------------------------------------------------------

proc loadShortstatehashInfo*(self: Service;
                             shortstatehash: ShortStateHash): seq[ShortStateInfo] =
  ## Ported from `load_shortstatehash_info`.
  ##
  ## Loads the state chain for a given state hash, walking up the parent
  ## chain and accumulating full state at each layer.

  # Check cache
  withLock self.cacheLock:
    if shortstatehash in self.stateinfoCache:
      return self.stateinfoCache[shortstatehash]

  # Walk up the parent chain
  var stack: seq[ShortStateInfo] = @[]
  var current = shortstatehash

  while true:
    if current notin self.db:
      break

    let diff = self.db[current]

    # Compute full state: start from parent's full state + added - removed
    var fullState: CompressedState = @[]
    if diff.parent.isSome and stack.len > 0:
      # Clone parent's full state
      fullState = stack[^1].fullState

    # Remove entries
    for removed in diff.removed:
      let idx = fullState.find(removed)
      if idx >= 0:
        fullState.delete(idx)

    # Add entries
    for added in diff.added:
      fullState.add(added)

    stack.add(ShortStateInfo(
      shortstatehash: current,
      fullState: fullState,
      added: diff.added,
      removed: diff.removed,
    ))

    if diff.parent.isNone:
      break
    current = diff.parent.get()

  # Cache result
  withLock self.cacheLock:
    self.stateinfoCache[shortstatehash] = stack

  stack


proc cacheShortstatehashInfo*(self: Service; shortstatehash: ShortStateHash;
                              stack: seq[ShortStateInfo]) =
  ## Ported from `cache_shortstatehash_info`.
  withLock self.cacheLock:
    self.stateinfoCache[shortstatehash] = stack


proc newShortstatehashInfo*(self: Service;
                            shortstatehash: ShortStateHash): seq[ShortStateInfo] =
  ## Ported from `new_shortstatehash_info`.
  ## Creates a fresh state info chain for a new state hash.
  self.loadShortstatehashInfo(shortstatehash)

# ---------------------------------------------------------------------------
# State saving
# ---------------------------------------------------------------------------

proc saveStateFromDiff*(self: Service; shortstatehash: ShortStateHash;
                        statediffnew, statediffremoved: CompressedState;
                        diffToSibling: int;
                        parentStates: seq[ShortStateInfo]) =
  ## Ported from `save_state_from_diff`.
  ##
  ## Saves a state hash with its diff relative to a parent.
  ## The parent is determined from parentStates.

  let parent = if parentStates.len > 0:
    some(parentStates[^1].shortstatehash)
  else:
    none(ShortStateHash)

  self.db[shortstatehash] = StateDiff(
    parent: parent,
    added: statediffnew,
    removed: statediffremoved,
  )

  debug "save_state_from_diff: hash=", shortstatehash, " added=", statediffnew.len,
        " removed=", statediffremoved.len


proc saveState*(self: Service; roomId: string;
                newStateIdsCompressed: CompressedState):
    tuple[shortstatehash: ShortStateHash, added: CompressedState, removed: CompressedState] =
  ## Ported from `save_state`.
  ##
  ## Computes the diff between current and new state, saves it,
  ## and returns the new state hash with added/removed diffs.

  # In real impl:
  # 1. Get current room shortstatehash
  # 2. Load current compressed state
  # 3. Compute diff (added = in new but not old, removed = in old but not new)
  # 4. Compute new hash
  # 5. Save diff
  # 6. Return (newhash, added, removed)

  var hash: ShortStateHash = 0
  for (k, v) in newStateIdsCompressed:
    hash = hash xor (k * 2654435761'u64) xor v

  (shortstatehash: hash, added: newStateIdsCompressed, removed: @[])


proc getStatediff*(self: Service; shortstatehash: ShortStateHash): Option[StateDiff] =
  ## Ported from `get_statediff`.
  if shortstatehash in self.db:
    some(self.db[shortstatehash])
  else:
    none(StateDiff)


proc saveStatediff*(self: Service; shortstatehash: ShortStateHash; diff: StateDiff) =
  ## Ported from `save_statediff`.
  self.db[shortstatehash] = diff

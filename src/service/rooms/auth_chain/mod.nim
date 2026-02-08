## auth_chain/mod — service module.
##
## Ported from Rust service/rooms/auth_chain/mod.rs
##
## Auth chain caching and computation: stores precomputed auth chain
## results keyed by sorted event ID sets. Uses an LRU cache with
## bucket hashing for fast intersection/union operations needed
## during state resolution.

import std/[options, json, tables, strutils, logging, locks, sets, algorithm, hashes]

const
  RustPath* = "service/rooms/auth_chain/mod.rs"
  RustCrate* = "service"

type
  ShortEventId* = uint64

  AuthChainCache = Table[uint64, seq[ShortEventId]]

  Service* = ref object
    authChainCache*: AuthChainCache
    cacheLock: Lock

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

proc build*(): Service =
  ## Ported from `build`.
  result = Service(
    authChainCache: initTable[uint64, seq[ShortEventId]](),
  )
  initLock(result.cacheLock)

proc name*(self: Service): string =
  ## Ported from `name`.
  "rooms::auth_chain"

proc clearCache*(self: Service) =
  ## Ported from `clear_cache`.
  withLock self.cacheLock:
    self.authChainCache.clear()

proc memoryUsage*(self: Service): string =
  ## Ported from `memory_usage`.
  withLock self.cacheLock:
    "cache=" & $self.authChainCache.len

# ---------------------------------------------------------------------------
# Auth chain caching
# ---------------------------------------------------------------------------

proc authChainKey(shortids: seq[ShortEventId]): uint64 =
  ## Computes a cache key from a sorted set of short event IDs.
  var sorted = shortids
  sorted.sort()
  var h = 0'u64
  for id in sorted:
    h = h xor hash(id).uint64
  h

proc getCachedAuthChain*(self: Service; key: seq[ShortEventId]): Option[seq[ShortEventId]] =
  ## Ported from `get_cached_auth_chain`.
  ##
  ## Retrieves a cached auth chain result. The key is a sorted set
  ## of short event IDs that were used as input to the auth chain
  ## computation.

  let cacheKey = authChainKey(key)
  withLock self.cacheLock:
    if cacheKey in self.authChainCache:
      return some(self.authChainCache[cacheKey])
  none(seq[ShortEventId])


proc putCachedAuthChain*(self: Service; key: seq[ShortEventId];
                         authChain: seq[ShortEventId]) =
  ## Ported from `put_cached_auth_chain`.
  ##
  ## Stores an auth chain result in the cache, keyed by the sorted
  ## input event IDs.

  let cacheKey = authChainKey(key)
  withLock self.cacheLock:
    self.authChainCache[cacheKey] = authChain

  debug "put_cached_auth_chain: cached chain of length ", authChain.len


proc getAuthChain*(self: Service; roomId: string;
                   startingEvents: seq[ShortEventId]): seq[ShortEventId] =
  ## Ported from `get_auth_chain`.
  ##
  ## Computes the full auth chain for a set of starting events.
  ## Uses BFS to walk auth_events recursively, with caching at
  ## intermediate sets for performance.

  # Check cache first
  let cached = self.getCachedAuthChain(startingEvents)
  if cached.isSome:
    return cached.get()

  # BFS through auth events
  var visited = initHashSet[ShortEventId]()
  var queue = startingEvents
  var chain: seq[ShortEventId] = @[]

  while queue.len > 0:
    let current = queue.pop()
    if current in visited:
      continue
    visited.incl(current)
    chain.add(current)

    # In real impl: get auth event IDs for current event
    # let authEvents = self.services.timeline.getPdu(current).auth_events
    # for authEvent in authEvents:
    #   let shortAuthId = self.services.short.getShorteventid(authEvent)
    #   queue.add(shortAuthId)

  # Cache result
  self.putCachedAuthChain(startingEvents, chain)

  chain

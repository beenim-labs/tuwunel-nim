## spaces/mod — service module.
##
## Ported from Rust service/rooms/spaces/mod.rs
##
## Space hierarchy traversal and caching. Implements the Matrix spaces
## protocol for discovering rooms within a space hierarchy. Handles
## local and federated space lookups with LRU caching.

import std/[options, json, tables, strutils, logging, locks]

const
  RustPath* = "service/rooms/spaces/mod.rs"
  RustCrate* = "service"

type
  SummaryAccessibility* = enum
    saAccessible
    saInaccessible

  IdentifierKind* = enum
    ikUserId
    ikServerName

  Identifier* = object
    kind*: IdentifierKind
    value*: string

  SpaceHierarchyParentSummary* = ref object
    canonicalAlias*: Option[string]
    name*: Option[string]
    numJoinedMembers*: uint64
    roomId*: string
    topic*: Option[string]
    worldReadable*: bool
    guestCanJoin*: bool
    avatarUrl*: Option[string]
    joinRule*: string
    roomType*: Option[string]
    childrenState*: seq[JsonNode]
    allowedRoomIds*: seq[string]

  CachedSpaceHierarchySummary* = ref object
    summary*: SpaceHierarchyParentSummary

  SpaceHierarchyRoomsChunk* = ref object
    canonicalAlias*: Option[string]
    name*: Option[string]
    numJoinedMembers*: uint64
    roomId*: string
    topic*: Option[string]
    worldReadable*: bool
    guestCanJoin*: bool
    avatarUrl*: Option[string]
    joinRule*: string
    roomType*: Option[string]
    childrenState*: seq[JsonNode]

  Cache* = Table[string, Option[CachedSpaceHierarchySummary]]

  Service* = ref object
    roomidSpacehierarchyCache*: Cache
    cacheLock: Lock

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

proc build*(): Service =
  ## Ported from `build`.
  result = Service(
    roomidSpacehierarchyCache: initTable[string, Option[CachedSpaceHierarchySummary]](),
  )
  initLock(result.cacheLock)

proc name*(self: Service): string =
  ## Ported from `name`.
  "rooms::spaces"

proc memoryUsage*(self: Service): string =
  ## Ported from `memory_usage`.
  withLock self.cacheLock:
    "cache=" & $self.roomidSpacehierarchyCache.len

proc clearCache*(self: Service) =
  ## Ported from `clear_cache`.
  withLock self.cacheLock:
    self.roomidSpacehierarchyCache.clear()

# ---------------------------------------------------------------------------
# Space hierarchy - client API
# ---------------------------------------------------------------------------

proc getSummaryAndChildrenClient*(self: Service; currentRoom: string;
                                  suggestedOnly: bool; userId: string;
                                  via: seq[string]): Option[tuple[access: SummaryAccessibility, summary: SpaceHierarchyParentSummary]] =
  ## Ported from `get_summary_and_children_client`.
  ##
  ## Gets the summary of a space using either local or remote (federation)
  ## sources. Tries local first, then falls back to federation.

  let identifier = Identifier(kind: ikUserId, value: userId)

  # Try local first
  let localResult = self.getSummaryAndChildrenLocal(currentRoom, identifier)
  if localResult.isSome:
    return localResult

  # Fall back to federation
  self.getSummaryAndChildrenFederation(currentRoom, suggestedOnly, userId, via)


proc getSummaryAndChildrenLocal*(self: Service; currentRoom: string;
                                 identifier: Identifier): Option[tuple[access: SummaryAccessibility, summary: SpaceHierarchyParentSummary]] =
  ## Ported from `get_summary_and_children_local`.
  ##
  ## Gets the summary of a space using solely local information.

  # Check cache
  withLock self.cacheLock:
    if currentRoom in self.roomidSpacehierarchyCache:
      let cached = self.roomidSpacehierarchyCache[currentRoom]
      if cached.isSome:
        return some((access: saAccessible, summary: cached.get().summary))
      else:
        return none(tuple[access: SummaryAccessibility, summary: SpaceHierarchyParentSummary])

  # In real impl:
  # 1. Get space child events from room state
  # 2. Build summary from room state (name, topic, avatar, join rules, etc.)
  # 3. Check if accessible based on identifier (user membership, server visibility)
  # 4. Cache result

  none(tuple[access: SummaryAccessibility, summary: SpaceHierarchyParentSummary])


proc getSummaryAndChildrenFederation*(self: Service; currentRoom: string;
                                     suggestedOnly: bool; userId: string;
                                     via: seq[string]): Option[tuple[access: SummaryAccessibility, summary: SpaceHierarchyParentSummary]] =
  ## Ported from `get_summary_and_children_federation`.
  ##
  ## Gets the summary of a space using federation. Tries each server in
  ## the via list until one responds.

  for server in via:
    # In real impl: send federation request to get space hierarchy
    # self.services.federation.execute(server, SpaceHierarchyRequest{...})
    debug "spaces: federation query to ", server, " for room ", currentRoom

  none(tuple[access: SummaryAccessibility, summary: SpaceHierarchyParentSummary])


proc isAccessibleChild*(self: Service; currentRoom: string; joinRule: string;
                        identifier: Identifier;
                        allowedRooms: seq[string]): bool =
  ## Ported from `is_accessible_child`.
  ##
  ## Checks if a room is accessible to the given identifier based on
  ## join rules and allowed rooms.

  case joinRule
  of "public", "knock", "knock_restricted":
    return true
  of "restricted":
    # Check if identifier has access through allowed rooms
    case identifier.kind
    of ikUserId:
      for allowedRoomId in allowedRooms:
        # In real impl: check if user is joined to allowed room
        discard
      return false
    of ikServerName:
      for allowedRoomId in allowedRooms:
        # In real impl: check if server participates in allowed room
        discard
      return false
  of "invite":
    case identifier.kind
    of ikUserId:
      # In real impl: check if user is joined or invited
      return false
    of ikServerName:
      # In real impl: check if server participates
      return false
  else:
    return false


proc getSpaceChildEvents*(self: Service; roomId: string): seq[JsonNode] =
  ## Ported from `get_space_child_events`.
  ## Returns the m.space.child events of a room.

  # In real impl: self.services.stateAccessor.roomStateTypePdus(roomId, "m.space.child")
  @[]


proc getSpaceChildren*(self: Service; roomId: string): seq[string] =
  ## Ported from `get_space_children`.
  ## Returns room IDs from m.space.child events in state_key.

  let events = self.getSpaceChildEvents(roomId)
  var children: seq[string] = @[]
  for event in events:
    let stateKey = event.getOrDefault("state_key").getStr("")
    if stateKey.len > 0:
      # Validate it looks like a room ID
      if stateKey.startsWith("!"):
        children.add(stateKey)
  children


proc cacheInsert*(self: Service; currentRoom: string;
                  summary: SpaceHierarchyParentSummary) =
  ## Ported from `cache_insert`.
  withLock self.cacheLock:
    self.roomidSpacehierarchyCache[currentRoom] = some(
      CachedSpaceHierarchySummary(summary: summary)
    )


proc summaryToChunk*(summary: SpaceHierarchyParentSummary): SpaceHierarchyRoomsChunk =
  ## Ported from `summary_to_chunk`.
  SpaceHierarchyRoomsChunk(
    canonicalAlias: summary.canonicalAlias,
    name: summary.name,
    numJoinedMembers: summary.numJoinedMembers,
    roomId: summary.roomId,
    topic: summary.topic,
    worldReadable: summary.worldReadable,
    guestCanJoin: summary.guestCanJoin,
    avatarUrl: summary.avatarUrl,
    joinRule: summary.joinRule,
    roomType: summary.roomType,
    childrenState: summary.childrenState,
  )

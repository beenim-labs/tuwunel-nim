## state_cache/mod — service module.
##
## Ported from Rust service/rooms/state_cache/mod.rs
##
## Maintains cached membership and room state data including:
##   - Room member counts (joined, invited, knocked)
##   - Server participation tracking
##   - Appservice-in-room cache
##   - User membership state queries (joined, invited, knocked, left)
##   - Shared room lookups

import std/[options, json, tables, strutils, logging, locks, sets, sequtils, algorithm]

const
  RustPath* = "service/rooms/state_cache/mod.rs"
  RustCrate* = "service"

type
  MembershipState* = enum
    msJoin = "join"
    msInvite = "invite"
    msKnock = "knock"
    msLeave = "leave"
    msBan = "ban"

  AppServiceInRoomCache* = Table[string, Table[string, bool]]

  Data* = ref object
    ## Database maps for membership tracking.
    roomidKnockedcount*: Table[string, uint64]
    roomidInvitedcount*: Table[string, uint64]
    roomidInviteviaservers*: Table[string, seq[string]]
    roomidJoinedcount*: Table[string, uint64]
    roomserverids*: Table[string, bool]          # (roomId, server) → exists
    roomuseridInvitecount*: Table[string, uint64]
    roomuseridJoinedcount*: Table[string, uint64]
    roomuseridLeftcount*: Table[string, uint64]
    roomuseridKnockedcount*: Table[string, uint64]
    roomuseroncejoinedids*: Table[string, bool]
    serverroomids*: Table[string, bool]          # (server, roomId) → exists
    userroomidInvitestate*: Table[string, JsonNode]
    userroomidJoinedcount*: Table[string, uint64]
    userroomidLeftstate*: Table[string, JsonNode]
    userroomidKnockedstate*: Table[string, JsonNode]

  Service* = ref object
    appserviceInRoomCache*: AppServiceInRoomCache
    appserviceCacheLock: Lock
    db*: Data

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

proc newData*(): Data =
  Data(
    roomidKnockedcount: initTable[string, uint64](),
    roomidInvitedcount: initTable[string, uint64](),
    roomidInviteviaservers: initTable[string, seq[string]](),
    roomidJoinedcount: initTable[string, uint64](),
    roomserverids: initTable[string, bool](),
    roomuseridInvitecount: initTable[string, uint64](),
    roomuseridJoinedcount: initTable[string, uint64](),
    roomuseridLeftcount: initTable[string, uint64](),
    roomuseridKnockedcount: initTable[string, uint64](),
    roomuseroncejoinedids: initTable[string, bool](),
    serverroomids: initTable[string, bool](),
    userroomidInvitestate: initTable[string, JsonNode](),
    userroomidJoinedcount: initTable[string, uint64](),
    userroomidLeftstate: initTable[string, JsonNode](),
    userroomidKnockedstate: initTable[string, JsonNode](),
  )

proc build*(): Service =
  ## Ported from `build`.
  result = Service(
    appserviceInRoomCache: initTable[string, Table[string, bool]](),
    db: newData(),
  )
  initLock(result.appserviceCacheLock)

proc name*(self: Service): string =
  ## Ported from `name`.
  "rooms::state_cache"

# ---------------------------------------------------------------------------
# Appservice-in-room cache
# ---------------------------------------------------------------------------

proc appserviceInRoom*(self: Service; roomId: string;
                       appserviceId: string; senderLocalpart: string;
                       serverName: string): bool =
  ## Ported from `appservice_in_room`.
  ## Checks if an appservice has a user in the room, using the cache.

  # Check cache first
  withLock self.appserviceCacheLock:
    if roomId in self.appserviceInRoomCache:
      let roomCache = self.appserviceInRoomCache[roomId]
      if appserviceId in roomCache:
        return roomCache[appserviceId]

  # Check if bridge user is joined
  let bridgeUserId = "@" & senderLocalpart & ":" & serverName
  let inRoom = self.isJoined(bridgeUserId, roomId)
  # In real impl: also check room_members against appservice user regex

  # Update cache
  withLock self.appserviceCacheLock:
    if roomId notin self.appserviceInRoomCache:
      self.appserviceInRoomCache[roomId] = initTable[string, bool]()
    self.appserviceInRoomCache[roomId][appserviceId] = inRoom

  inRoom

proc getAppserviceInRoomCacheUsage*(self: Service): tuple[count: int, capacity: int] =
  ## Ported from `get_appservice_in_room_cache_usage`.
  withLock self.appserviceCacheLock:
    result = (count: self.appserviceInRoomCache.len, capacity: self.appserviceInRoomCache.len)

proc clearAppserviceInRoomCache*(self: Service) =
  ## Ported from `clear_appservice_in_room_cache`.
  withLock self.appserviceCacheLock:
    self.appserviceInRoomCache.clear()

# ---------------------------------------------------------------------------
# Server participation
# ---------------------------------------------------------------------------

proc roomServerKey(roomId, server: string): string =
  roomId & "\xFF" & server

proc serverRoomKey(server, roomId: string): string =
  server & "\xFF" & roomId

proc roomServers*(self: Service; roomId: string): seq[string] =
  ## Ported from `room_servers`.
  ## Returns all servers participating in this room.
  let prefix = roomId & "\xFF"
  for key in self.db.roomserverids.keys:
    if key.startsWith(prefix):
      result.add(key[prefix.len ..< key.len])

proc serverInRoom*(self: Service; server, roomId: string): bool =
  ## Ported from `server_in_room`.
  serverRoomKey(server, roomId) in self.db.serverroomids

proc serverRooms*(self: Service; server: string): seq[string] =
  ## Ported from `server_rooms`.
  ## Returns all rooms a server participates in.
  let prefix = server & "\xFF"
  for key in self.db.serverroomids.keys:
    if key.startsWith(prefix):
      result.add(key[prefix.len ..< key.len])

proc serverSeesUser*(self: Service; server, userId: string): bool =
  ## Ported from `server_sees_user`.
  ## Returns true if server can see user by sharing at least one room.
  for roomId in self.serverRooms(server):
    if self.isJoined(userId, roomId):
      return true
  false

proc userSeesUser*(self: Service; userA, userB: string): bool =
  ## Ported from `user_sees_user`.
  ## Returns true if userA and userB share at least one room.
  let sharedRooms = self.getSharedRooms(userA, userB)
  sharedRooms.len > 0

proc getSharedRooms*(self: Service; userA, userB: string): seq[string] =
  ## Ported from `get_shared_rooms`.
  ## Returns rooms common between two users.
  let roomsA = self.roomsJoined(userA).toHashSet()
  for roomId in self.roomsJoined(userB):
    if roomId in roomsA:
      result.add(roomId)

# ---------------------------------------------------------------------------
# Room members
# ---------------------------------------------------------------------------

proc userRoomKey(userId, roomId: string): string =
  userId & "\xFF" & roomId

proc roomUserKey(roomId, userId: string): string =
  roomId & "\xFF" & userId

proc roomMembers*(self: Service; roomId: string): seq[string] =
  ## Ported from `room_members`.
  ## Returns all joined members of a room.
  let prefix = roomId & "\xFF"
  for key in self.db.roomuseridJoinedcount.keys:
    if key.startsWith(prefix):
      result.add(key[prefix.len ..< key.len])

proc roomJoinedCount*(self: Service; roomId: string): uint64 =
  ## Ported from `room_joined_count`.
  self.db.roomidJoinedcount.getOrDefault(roomId, 0)

proc roomInvitedCount*(self: Service; roomId: string): uint64 =
  ## Ported from `room_invited_count`.
  self.db.roomidInvitedcount.getOrDefault(roomId, 0)

proc roomKnockedCount*(self: Service; roomId: string): uint64 =
  ## Ported from `room_knocked_count`.
  self.db.roomidKnockedcount.getOrDefault(roomId, 0)

proc activeLocalUsersInRoom*(self: Service; roomId: string;
                             isLocal: proc(userId: string): bool;
                             isActive: proc(userId: string): bool): seq[string] =
  ## Ported from `active_local_users_in_room`.
  for userId in self.roomMembers(roomId):
    if isLocal(userId) and isActive(userId):
      result.add(userId)

proc localUsersInRoom*(self: Service; roomId: string;
                       isLocal: proc(userId: string): bool): seq[string] =
  ## Ported from `local_users_in_room`.
  for userId in self.roomMembers(roomId):
    if isLocal(userId):
      result.add(userId)

proc localUsersInvitedToRoom*(self: Service; roomId: string;
                              isLocal: proc(userId: string): bool): seq[string] =
  ## Ported from `local_users_invited_to_room`.
  for userId in self.roomMembersInvited(roomId):
    if isLocal(userId):
      result.add(userId)

proc roomUseroncejoined*(self: Service; roomId: string): seq[string] =
  ## Ported from `room_useroncejoined`.
  ## Returns all users who ever joined a room.
  let prefix = roomId & "\xFF"
  for key in self.db.roomuseroncejoinedids.keys:
    if key.startsWith(prefix):
      result.add(key[prefix.len ..< key.len])

proc roomMembersInvited*(self: Service; roomId: string): seq[string] =
  ## Ported from `room_members_invited`.
  let prefix = roomId & "\xFF"
  for key in self.db.roomuseridInvitecount.keys:
    if key.startsWith(prefix):
      result.add(key[prefix.len ..< key.len])

proc roomMembersKnocked*(self: Service; roomId: string): seq[string] =
  ## Ported from `room_members_knocked`.
  let prefix = roomId & "\xFF"
  for key in self.db.roomuseridKnockedcount.keys:
    if key.startsWith(prefix):
      result.add(key[prefix.len ..< key.len])

# ---------------------------------------------------------------------------
# Per-user counts
# ---------------------------------------------------------------------------

proc getInviteCount*(self: Service; roomId, userId: string): uint64 =
  ## Ported from `get_invite_count`.
  self.db.roomuseridInvitecount.getOrDefault(roomUserKey(roomId, userId), 0)

proc getKnockCount*(self: Service; roomId, userId: string): uint64 =
  ## Ported from `get_knock_count`.
  self.db.roomuseridKnockedcount.getOrDefault(roomUserKey(roomId, userId), 0)

proc getLeftCount*(self: Service; roomId, userId: string): uint64 =
  ## Ported from `get_left_count`.
  self.db.roomuseridLeftcount.getOrDefault(roomUserKey(roomId, userId), 0)

proc getJoinedCount*(self: Service; roomId, userId: string): uint64 =
  ## Ported from `get_joined_count`.
  self.db.roomuseridJoinedcount.getOrDefault(roomUserKey(roomId, userId), 0)

# ---------------------------------------------------------------------------
# User rooms
# ---------------------------------------------------------------------------

proc roomsJoined*(self: Service; userId: string): seq[string] =
  ## Ported from `rooms_joined`.
  let prefix = userId & "\xFF"
  for key in self.db.userroomidJoinedcount.keys:
    if key.startsWith(prefix):
      result.add(key[prefix.len ..< key.len])

proc roomsInvited*(self: Service; userId: string): seq[string] =
  ## Ported from `rooms_invited`.
  let prefix = userId & "\xFF"
  for key in self.db.userroomidInvitestate.keys:
    if key.startsWith(prefix):
      result.add(key[prefix.len ..< key.len])

proc roomsKnocked*(self: Service; userId: string): seq[string] =
  ## Ported from `rooms_knocked`.
  let prefix = userId & "\xFF"
  for key in self.db.userroomidKnockedstate.keys:
    if key.startsWith(prefix):
      result.add(key[prefix.len ..< key.len])

proc roomsLeft*(self: Service; userId: string): seq[string] =
  ## Ported from `rooms_left`.
  let prefix = userId & "\xFF"
  for key in self.db.userroomidLeftstate.keys:
    if key.startsWith(prefix):
      result.add(key[prefix.len ..< key.len])

# ---------------------------------------------------------------------------
# Membership state queries
# ---------------------------------------------------------------------------

proc inviteState*(self: Service; userId, roomId: string): Option[JsonNode] =
  ## Ported from `invite_state`.
  let key = userRoomKey(userId, roomId)
  if key in self.db.userroomidInvitestate:
    some(self.db.userroomidInvitestate[key])
  else:
    none(JsonNode)

proc knockState*(self: Service; userId, roomId: string): Option[JsonNode] =
  ## Ported from `knock_state`.
  let key = userRoomKey(userId, roomId)
  if key in self.db.userroomidKnockedstate:
    some(self.db.userroomidKnockedstate[key])
  else:
    none(JsonNode)

proc leftState*(self: Service; userId, roomId: string): Option[JsonNode] =
  ## Ported from `left_state`.
  let key = userRoomKey(userId, roomId)
  if key in self.db.userroomidLeftstate:
    some(self.db.userroomidLeftstate[key])
  else:
    none(JsonNode)

proc userMembership*(self: Service; userId, roomId: string): Option[MembershipState] =
  ## Ported from `user_membership`.
  ## Checks all membership states (join, leave, knock, invite) and returns
  ## the current one. Falls back to Ban if user once-joined but has no
  ## current membership.
  let joined = self.isJoined(userId, roomId)
  let left = self.isLeft(userId, roomId)
  let knocked = self.isKnocked(userId, roomId)
  let invited = self.isInvited(userId, roomId)
  let onceJoined = self.onceJoined(userId, roomId)

  if joined: return some(msJoin)
  if left: return some(msLeave)
  if knocked: return some(msKnock)
  if invited: return some(msInvite)
  if onceJoined: return some(msBan)
  none(MembershipState)

proc onceJoined*(self: Service; userId, roomId: string): bool =
  ## Ported from `once_joined`.
  userRoomKey(userId, roomId) in self.db.roomuseroncejoinedids

proc isJoined*(self: Service; userId, roomId: string): bool =
  ## Ported from `is_joined`.
  userRoomKey(userId, roomId) in self.db.userroomidJoinedcount

proc isKnocked*(self: Service; userId, roomId: string): bool =
  ## Ported from `is_knocked`.
  userRoomKey(userId, roomId) in self.db.userroomidKnockedstate

proc isInvited*(self: Service; userId, roomId: string): bool =
  ## Ported from `is_invited`.
  userRoomKey(userId, roomId) in self.db.userroomidInvitestate

proc isLeft*(self: Service; userId, roomId: string): bool =
  ## Ported from `is_left`.
  userRoomKey(userId, roomId) in self.db.userroomidLeftstate

# ---------------------------------------------------------------------------
# Membership enumeration with filter
# ---------------------------------------------------------------------------

proc allUserMemberships*(self: Service; userId: string): seq[tuple[state: MembershipState, roomId: string]] =
  ## Ported from `all_user_memberships`.
  self.userMemberships(userId, @[])

proc userMemberships*(self: Service; userId: string;
                      mask: seq[MembershipState]): seq[tuple[state: MembershipState, roomId: string]] =
  ## Ported from `user_memberships`.
  ## Returns all rooms with their membership state for a user.
  ## If mask is empty, returns all memberships. Otherwise only returns
  ## memberships matching the mask.

  if mask.len == 0 or msJoin in mask:
    for roomId in self.roomsJoined(userId):
      result.add((state: msJoin, roomId: roomId))

  if mask.len == 0 or msInvite in mask:
    for roomId in self.roomsInvited(userId):
      result.add((state: msInvite, roomId: roomId))

  if mask.len == 0 or msKnock in mask:
    for roomId in self.roomsKnocked(userId):
      result.add((state: msKnock, roomId: roomId))

  if mask.len == 0 or msLeave in mask:
    for roomId in self.roomsLeft(userId):
      result.add((state: msLeave, roomId: roomId))

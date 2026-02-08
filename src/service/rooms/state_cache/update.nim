## state_cache/update — service module.
##
## Ported from Rust service/rooms/state_cache/update.rs
##
## Handles all membership state mutations: joining, leaving, inviting,
## knocking, and forgetting rooms. Each mutation updates the relevant
## database maps and cleans up conflicting membership states.
## Also handles predecessor room tag/direct-chat copying on join.

import std/[options, json, tables, strutils, logging, sets]
import ./mod as state_cache_mod

const
  RustPath* = "service/rooms/state_cache/update.rs"
  RustCrate* = "service"

type
  PduCount* = uint64

proc updateMembership*(self: Service; roomId: string; userId: string;
                       membership: MembershipState; sender: string;
                       lastState: Option[JsonNode];
                       inviteVia: Option[seq[string]];
                       updateJoinedCount: bool;
                       count: PduCount) =
  ## Ported from `update_membership`.
  ##
  ## Main entry point for membership updates. Handles join/invite/leave/ban
  ## transitions including predecessor room tag copying and ignore checks.

  # Keep track of remote users by creating them as deactivated
  # In real impl: if not isLocal(userId) and not userExists(userId):
  #   self.services.users.create(userId, none, none)

  case membership
  of msJoin:
    # Check if user never joined this room before
    if not self.onceJoined(userId, roomId):
      self.markAsOnceJoined(userId, roomId)

      # Check if the room has a predecessor
      # In real impl: state_accessor.roomStateGetContent(roomId, "m.room.create", "")
      # If predecessor exists:
      #   - Copy old tags to new room
      #   - Copy direct chat flag
      debug "update_membership: user ", userId, " joining room ", roomId

    self.markAsJoined(userId, roomId, count)

  of msInvite:
    # Check if sender is ignored by receiver
    # In real impl: self.services.users.userIsIgnored(sender, userId)
    let isIgnored = false  # placeholder
    if isIgnored:
      debug "update_membership: invite from ", sender, " ignored by ", userId
      return

    self.markAsInvited(userId, roomId, count, lastState, inviteVia)

  of msLeave, msBan:
    self.markAsLeft(userId, roomId, count)

    # If local user and forced forget enabled, forget the room
    # In real impl: check config.forgetForcedUponLeave or room is banned/disabled
    # if isLocal(userId) and (forceForget or isBanned or isDisabled):
    #   self.forget(roomId, userId)

  of msKnock:
    discard  # Knock state handled separately

  if updateJoinedCount:
    self.updateJoinedCount(roomId)


proc updateJoinedCount*(self: Service; roomId: string) =
  ## Ported from `update_joined_count`.
  ##
  ## Recomputes joined/invited/knocked counts and updates server
  ## participation tracking. Called after membership changes.

  var joinedCount: uint64 = 0
  var invitedCount: uint64 = 0
  var knockedCount: uint64 = 0
  var joinedServers = initHashSet[string]()

  for userId in self.roomMembers(roomId):
    # Extract server name from user ID: @user:server.com → server.com
    let atIdx = userId.find('@')
    let colonIdx = userId.find(':', atIdx + 1)
    if colonIdx >= 0:
      let serverName = userId[colonIdx + 1 ..< userId.len]
      joinedServers.incl(serverName)
    joinedCount += 1

  invitedCount = self.roomMembersInvited(roomId).len.uint64
  knockedCount = self.roomMembersKnocked(roomId).len.uint64

  # Persist counts
  self.db.roomidJoinedcount[roomId] = joinedCount
  self.db.roomidInvitedcount[roomId] = invitedCount
  self.db.roomidKnockedcount[roomId] = knockedCount

  # Update server participation: remove servers no longer in room
  let currentServers = self.roomServers(roomId)
  for server in currentServers:
    if server notin joinedServers:
      let rsKey = roomServerKey(roomId, server)
      let srKey = serverRoomKey(server, roomId)
      self.db.roomserverids.del(rsKey)
      self.db.serverroomids.del(srKey)

  # Add new servers
  for server in joinedServers:
    let rsKey = roomServerKey(roomId, server)
    let srKey = serverRoomKey(server, roomId)
    self.db.roomserverids[rsKey] = true
    self.db.serverroomids[srKey] = true

  # Clear appservice cache for this room
  withLock self.appserviceCacheLock:
    self.appserviceInRoomCache.del(roomId)


proc markAsJoined*(self: Service; userId, roomId: string; count: PduCount) =
  ## Ported from `mark_as_joined`.
  ## Directly marks a user as joined in the database tables.
  ## Clears conflicting invite/left/knocked states.
  let urKey = userRoomKey(userId, roomId)
  let ruKey = roomUserKey(roomId, userId)

  # Set joined
  self.db.userroomidJoinedcount[urKey] = count
  self.db.roomuseridJoinedcount[ruKey] = count

  # Clear invite
  self.db.userroomidInvitestate.del(urKey)
  self.db.roomuseridInvitecount.del(ruKey)

  # Clear left
  self.db.userroomidLeftstate.del(urKey)
  self.db.roomuseridLeftcount.del(ruKey)

  # Clear knocked
  self.db.userroomidKnockedstate.del(urKey)
  self.db.roomuseridKnockedcount.del(ruKey)

  # Clear invite-via servers
  self.db.roomidInviteviaservers.del(roomId)

  debug "mark_as_joined: ", userId, " in ", roomId


proc markAsLeft*(self: Service; userId, roomId: string; count: PduCount) =
  ## Ported from `mark_as_left`.
  ## Directly marks a user as left. Clears all other membership states.
  let urKey = userRoomKey(userId, roomId)
  let ruKey = roomUserKey(roomId, userId)

  # Set left state (empty state events for now)
  self.db.userroomidLeftstate[urKey] = newJArray()
  self.db.roomuseridLeftcount[ruKey] = count

  # Clear joined
  self.db.userroomidJoinedcount.del(urKey)
  self.db.roomuseridJoinedcount.del(ruKey)

  # Clear invite
  self.db.userroomidInvitestate.del(urKey)
  self.db.roomuseridInvitecount.del(ruKey)

  # Clear knocked
  self.db.userroomidKnockedstate.del(urKey)
  self.db.roomuseridKnockedcount.del(ruKey)

  # Clear invite-via servers
  self.db.roomidInviteviaservers.del(roomId)

  debug "mark_as_left: ", userId, " from ", roomId


proc markAsKnocked*(self: Service; userId, roomId: string; count: PduCount;
                    knockedState: Option[JsonNode]) =
  ## Ported from `_mark_as_knocked`.
  ## Directly marks a user as knocking. Clears other membership states.
  let urKey = userRoomKey(userId, roomId)
  let ruKey = roomUserKey(roomId, userId)

  # Set knocked state
  self.db.userroomidKnockedstate[urKey] = knockedState.get(newJArray())
  self.db.roomuseridKnockedcount[ruKey] = count

  # Clear joined
  self.db.userroomidJoinedcount.del(urKey)
  self.db.roomuseridJoinedcount.del(ruKey)

  # Clear invite
  self.db.userroomidInvitestate.del(urKey)
  self.db.roomuseridInvitecount.del(ruKey)

  # Clear left
  self.db.userroomidLeftstate.del(urKey)
  self.db.roomuseridLeftcount.del(ruKey)

  # Clear invite-via servers
  self.db.roomidInviteviaservers.del(roomId)


proc forget*(self: Service; roomId, userId: string) =
  ## Ported from `forget`.
  ## Makes a user forget a room (removes left state).
  let urKey = userRoomKey(userId, roomId)
  let ruKey = roomUserKey(roomId, userId)

  self.db.userroomidLeftstate.del(urKey)
  self.db.roomuseridLeftcount.del(ruKey)

  debug "forget: ", userId, " forgot ", roomId


proc markAsOnceJoined*(self: Service; userId, roomId: string) =
  ## Ported from `mark_as_once_joined`.
  let key = userRoomKey(userId, roomId)
  self.db.roomuseroncejoinedids[key] = true


proc markAsInvited*(self: Service; userId, roomId: string; count: PduCount;
                    lastState: Option[JsonNode];
                    inviteVia: Option[seq[string]]) =
  ## Ported from `mark_as_invited`.
  ## Marks a user as invited. Clears other membership states.
  let urKey = userRoomKey(userId, roomId)
  let ruKey = roomUserKey(roomId, userId)

  # Set invite state
  self.db.userroomidInvitestate[urKey] = lastState.get(newJArray())
  self.db.roomuseridInvitecount[ruKey] = count

  # Clear joined
  self.db.userroomidJoinedcount.del(urKey)
  self.db.roomuseridJoinedcount.del(ruKey)

  # Clear left
  self.db.userroomidLeftstate.del(urKey)
  self.db.roomuseridLeftcount.del(ruKey)

  # Clear knocked
  self.db.userroomidKnockedstate.del(urKey)
  self.db.roomuseridKnockedcount.del(ruKey)

  # Store invite-via servers if provided
  if inviteVia.isSome and inviteVia.get().len > 0:
    self.addServersInviteVia(roomId, inviteVia.get())

  debug "mark_as_invited: ", userId, " to ", roomId


proc deleteRoomJoinCounts*(self: Service; roomId: string; force: bool) =
  ## Ported from `delete_room_join_counts`.
  ## Removes all join count data for a room. Used when purging a room.

  self.db.roomidKnockedcount.del(roomId)
  self.db.roomidInvitedcount.del(roomId)
  self.db.roomidInviteviaservers.del(roomId)
  self.db.roomidJoinedcount.del(roomId)

  # Remove server participation entries
  for server in self.roomServers(roomId):
    let rsKey = roomServerKey(roomId, server)
    let srKey = serverRoomKey(server, roomId)
    self.db.roomserverids.del(rsKey)
    self.db.serverroomids.del(srKey)

  # Remove invite counts
  for userId in self.roomMembersInvited(roomId):
    let ruKey = roomUserKey(roomId, userId)
    let urKey = userRoomKey(userId, roomId)
    self.db.roomuseridInvitecount.del(ruKey)
    self.db.userroomidInvitestate.del(urKey)

  # Remove joined counts
  for userId in self.roomMembers(roomId):
    let ruKey = roomUserKey(roomId, userId)
    let urKey = userRoomKey(userId, roomId)
    self.db.roomuseridJoinedcount.del(ruKey)
    self.db.userroomidJoinedcount.del(urKey)

  # Remove knocked counts
  for userId in self.roomMembersKnocked(roomId):
    let ruKey = roomUserKey(roomId, userId)
    let urKey = userRoomKey(userId, roomId)
    self.db.roomuseridKnockedcount.del(ruKey)
    self.db.userroomidKnockedstate.del(urKey)

  # Remove left counts (optionally only remote users)
  let prefix = roomId & "\xFF"
  var toRemove: seq[string] = @[]
  for key in self.db.roomuseridLeftcount.keys:
    if key.startsWith(prefix):
      let userId = key[prefix.len ..< key.len]
      # In real impl: check if force or not isLocal(userId)
      if force:
        toRemove.add(key)

  for key in toRemove:
    let userId = key[prefix.len ..< key.len]
    let urKey = userRoomKey(userId, roomId)
    self.db.roomuseridLeftcount.del(key)
    self.db.userroomidLeftstate.del(urKey)

  debug "delete_room_join_counts: cleaned up ", roomId

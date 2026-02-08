## alias/mod — service module.
##
## Ported from Rust service/rooms/alias/mod.rs
##
## Room alias management: setting, removing, resolving (local, remote,
## appservice), permission checking, and listing aliases.

import std/[options, json, tables, strutils, logging]

const
  RustPath* = "service/rooms/alias/mod.rs"
  RustCrate* = "service"

type
  Data* = ref object
    aliasUserid*: Table[string, string]    # alias → user_id (creator)
    aliasRoomid*: Table[string, string]    # alias → room_id
    aliasidAlias*: Table[string, string]   # (room_id+count) → alias

  Service* = ref object
    db*: Data
    serverName*: string  # our server name

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

proc build*(serverName: string): Service =
  ## Ported from `build`.
  Service(
    db: Data(
      aliasUserid: initTable[string, string](),
      aliasRoomid: initTable[string, string](),
      aliasidAlias: initTable[string, string](),
    ),
    serverName: serverName,
  )

proc name*(self: Service): string =
  ## Ported from `name`.
  "rooms::alias"

# ---------------------------------------------------------------------------
# Alias management
# ---------------------------------------------------------------------------

proc checkAliasLocal*(self: Service; alias: string) =
  ## Ported from `check_alias_local`.
  ## Validates that an alias belongs to our server.
  let parts = alias.split(':')
  if parts.len < 2 or parts[^1] != self.serverName:
    raise newException(ValueError, "Alias is from another server.")


proc setAlias*(self: Service; alias, roomId, userId: string) =
  ## Ported from `set_alias`.
  ## Creates a new room alias pointing to a room.

  self.checkAliasLocal(alias)

  # In real impl: check if alias == admin_alias and user != server_user
  # if alias == self.services.admin.adminAlias and userId != self.services.globals.serverUser:
  #   raise "Only the server user can set this alias"

  # Store alias → user (creator)
  self.db.aliasUserid[alias] = userId

  # Store alias → room
  self.db.aliasRoomid[alias] = roomId

  # Store room → alias (for reverse lookup)
  let key = roomId & "\xFF" & alias
  self.db.aliasidAlias[key] = alias

  debug "set_alias: ", alias, " → ", roomId, " by ", userId


proc removeAlias*(self: Service; alias, userId: string) =
  ## Ported from `remove_alias`.
  ## Removes a room alias after checking permissions.

  # In real impl: self.userCanRemoveAlias(alias, userId)
  let roomId = self.db.aliasRoomid.getOrDefault(alias, "")
  if roomId.len == 0:
    raise newException(ValueError, "Alias does not exist or is invalid.")

  # Remove reverse lookup entries
  let prefix = roomId & "\xFF"
  var toRemove: seq[string] = @[]
  for key in self.db.aliasidAlias.keys:
    if key.startsWith(prefix):
      toRemove.add(key)
  for key in toRemove:
    self.db.aliasidAlias.del(key)

  self.db.aliasRoomid.del(alias)
  self.db.aliasUserid.del(alias)

  debug "remove_alias: ", alias


proc maybeResolve*(self: Service; room: string): string =
  ## Ported from `maybe_resolve`.
  ## If the input is a room alias, resolves it. If it's already a room ID, returns it.
  if room.startsWith("!"):
    return room  # already a room ID
  elif room.startsWith("#"):
    let (roomId, _) = self.resolveAlias(room)
    return roomId
  raise newException(ValueError, "Invalid room identifier: " & room)


proc maybeResolveWithServers*(self: Service; room: string;
                              servers: Option[seq[string]]): tuple[roomId: string, servers: seq[string]] =
  ## Ported from `maybe_resolve_with_servers`.
  if room.startsWith("!"):
    return (roomId: room, servers: servers.get(@[]))
  elif room.startsWith("#"):
    return self.resolveAlias(room)
  raise newException(ValueError, "Invalid room identifier: " & room)


proc resolveAlias*(self: Service; roomAlias: string): tuple[roomId: string, servers: seq[string]] =
  ## Ported from `resolve_alias`.
  ##
  ## Resolves a room alias. Tries local first, then appservice, then remote.

  let parts = roomAlias.split(':')
  let aliasServer = if parts.len >= 2: parts[^1] else: ""

  if aliasServer == self.serverName:
    # Local alias
    let roomId = self.resolveLocalAlias(roomAlias)
    if roomId.len > 0:
      return (roomId: roomId, servers: @[])

    # Try appservice
    let appserviceResult = self.resolveAppserviceAlias(roomAlias)
    if appserviceResult.len > 0:
      return (roomId: appserviceResult, servers: @[])

    raise newException(ValueError, "Room with alias not found.")

  # Remote resolve
  return self.remoteResolve(roomAlias)


proc remoteResolve*(self: Service; roomAlias: string): tuple[roomId: string, servers: seq[string]] =
  ## Ported from `remote_resolve`.
  ##
  ## Resolves a room alias via federation.

  # In real impl: send federation request
  # let server = roomAlias.serverName()
  # let response = self.services.federation.execute(server, Request{room_alias: roomAlias})
  # return (response.roomId, response.servers)
  raise newException(ValueError, "Remote alias resolution not implemented")


proc resolveLocalAlias*(self: Service; alias: string): string =
  ## Ported from `resolve_local_alias`.
  self.checkAliasLocal(alias)
  self.db.aliasRoomid.getOrDefault(alias, "")


proc localAliasesForRoom*(self: Service; roomId: string): seq[string] =
  ## Ported from `local_aliases_for_room`.
  ## Returns all local aliases for a room.
  let prefix = roomId & "\xFF"
  for key, alias in self.db.aliasidAlias:
    if key.startsWith(prefix):
      result.add(alias)


proc allLocalAliases*(self: Service): seq[tuple[roomId: string, alias: string]] =
  ## Ported from `all_local_aliases`.
  ## Returns all local aliases as (room_id, alias) pairs.
  for alias, roomId in self.db.aliasRoomid:
    result.add((roomId: roomId, alias: alias))


proc userCanRemoveAlias*(self: Service; alias, userId: string): bool =
  ## Ported from `user_can_remove_alias`.
  ##
  ## Checks if a user can remove an alias. Allowed if:
  ## - User created the alias
  ## - User is a server admin
  ## - User is the server service account
  ## - User has power to change canonical aliases

  self.checkAliasLocal(alias)

  let roomId = self.resolveLocalAlias(alias)
  if roomId.len == 0:
    raise newException(ValueError, "Alias not found.")

  # Check if creator
  let creator = self.whoCreatedAlias(alias)
  if creator == userId:
    return true

  # In real impl: check admin status
  # if self.services.admin.userIsAdmin(userId): return true
  # if self.services.globals.serverUser == userId: return true

  # In real impl: check power levels for canonical alias changes
  # let powerLevels = self.services.stateAccessor.getPowerLevels(roomId)
  # return powerLevels.userCanSendState(userId, "m.room.canonical_alias")

  false


proc whoCreatedAlias*(self: Service; alias: string): string =
  ## Ported from `who_created_alias`.
  self.db.aliasUserid.getOrDefault(alias, "")


proc resolveAppserviceAlias*(self: Service; roomAlias: string): string =
  ## Ported from `resolve_appservice_alias`.
  ## Tries to resolve an alias through registered appservices.

  self.checkAliasLocal(roomAlias)

  # In real impl: iterate appservices, check regex match, query appservice
  # for appservice in self.services.appservice.read().values:
  #   if appservice.aliases.isMatch(roomAlias):
  #     send query to appservice
  #     return self.resolveLocalAlias(roomAlias)
  ""


proc appserviceChecks*(self: Service; roomAlias: string;
                       hasAppserviceInfo: bool; aliasRegexMatch: bool) =
  ## Ported from `appservice_checks`.
  ## Validates alias permissions for appservices.

  self.checkAliasLocal(roomAlias)

  if hasAppserviceInfo:
    if not aliasRegexMatch:
      raise newException(ValueError, "Room alias is not in namespace.")
  else:
    # In real impl: check if any appservice has exclusive claim
    # if self.services.appservice.isExclusiveAlias(roomAlias):
    #   raise "Room alias reserved by appservice."
    discard

## state_cache/via — service module.
##
## Ported from Rust service/rooms/state_cache/via.rs
##
## Manages invite-via server lists and computes recommended routing
## servers for rooms following the Matrix spec appendix on routing.

import std/[options, json, tables, strutils, logging, sequtils, algorithm]
import ./mod as state_cache_mod

const
  RustPath* = "service/rooms/state_cache/via.rs"
  RustCrate* = "service"

proc addServersInviteVia*(self: Service; roomId: string; servers: seq[string]) =
  ## Ported from `add_servers_invite_via`.
  ##
  ## Adds servers to the room's invite-via server list, merging with
  ## any existing servers and deduplicating.

  # Get existing servers
  var allServers = self.serversInviteVia(roomId)

  # Merge new servers
  for server in servers:
    allServers.add(server)

  # Sort and deduplicate
  allServers.sort()
  allServers = allServers.deduplicate(isSorted = true)

  # Store merged list
  self.db.roomidInviteviaservers[roomId] = allServers

  debug "add_servers_invite_via: ", allServers.len, " servers for room ", roomId


proc serversRouteVia*(self: Service; roomId: string): seq[string] =
  ## Ported from `servers_route_via`.
  ##
  ## Gets up to five servers likely to be in the room in the distant future.
  ## Follows the Matrix spec routing appendix:
  ##   1. Find the most powerful user with power level >= 50
  ##   2. Count members per server
  ##   3. Sort by member count descending
  ##   4. Take top 5
  ##   5. Insert most powerful user's server at front

  # In real impl: fetch room power levels from state
  # let powerLevels = self.services.stateAccessor.roomStateGetContent(
  #   roomId, "m.room.power_levels", "")
  var mostPowerfulServer = ""

  # In real impl: find user with highest power level >= 50
  # for (userId, power) in powerLevels.users:
  #   if power >= 50 and power > maxPower:
  #     maxPower = power
  #     mostPowerfulServer = userId.serverName()

  # Count members per server
  var serverCounts = initTable[string, int]()
  for userId in self.roomMembers(roomId):
    let colonIdx = userId.find(':')
    if colonIdx >= 0:
      let server = userId[colonIdx + 1 ..< userId.len]
      serverCounts.mgetOrPut(server, 0) += 1

  # Sort by count descending, take top 5
  var serverList: seq[tuple[server: string, count: int]] = @[]
  for (server, count) in serverCounts.pairs:
    serverList.add((server: server, count: count))
  serverList.sort(proc(a, b: tuple[server: string, count: int]): int =
    cmp(b.count, a.count))

  var result: seq[string] = @[]
  for i in 0 ..< min(serverList.len, 5):
    result.add(serverList[i].server)

  # Insert most powerful user's server at front if found
  if mostPowerfulServer.len > 0:
    result.insert(mostPowerfulServer, 0)
    if result.len > 5:
      result.setLen(5)

  result


proc serversInviteVia*(self: Service; roomId: string): seq[string] =
  ## Ported from `servers_invite_via`.
  ## Returns the stored invite-via servers for a room.

  if roomId in self.db.roomidInviteviaservers:
    return self.db.roomidInviteviaservers[roomId]
  @[]

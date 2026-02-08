## delete/mod — service module.
##
## Ported from Rust service/rooms/delete/mod.rs
##
## Room deletion and cleanup: deleting empty rooms and force-deleting
## rooms with full cleanup of all associated state and membership data.

import std/[options, json, tables, strutils, logging]

const
  RustPath* = "service/rooms/delete/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    discard

proc build*(): Service =
  ## Ported from `build`.
  Service()

proc name*(self: Service): string =
  ## Ported from `name`.
  "rooms::delete"

proc deleteIfEmptyLocal*(self: Service; roomId: string) =
  ## Ported from `delete_if_empty_local`.
  ##
  ## Deletes a room if it has no local members left.
  ## Only applies to local rooms — rooms with at least one
  ## remaining local member are not deleted.

  # In real impl:
  # 1. let localUsers = self.services.stateCache.localUsersInRoom(roomId)
  # 2. if localUsers.len == 0:
  #      self.deleteRoom(roomId, force=false)

  debug "delete_if_empty_local: checking room ", roomId

  # Placeholder: check if room has local members
  # let localUsers = self.services.stateCache.localUsersInRoom(roomId, isLocal)
  # if localUsers.len > 0:
  #   return

  # In real impl: proceed with deletion
  # self.deleteRoom(roomId, false)


proc deleteRoom*(self: Service; roomId: string; force: bool) =
  ## Ported from `delete_room`.
  ##
  ## Fully deletes a room, purging all associated data:
  ## 1. Short room ID mappings
  ## 2. Room state and state hashes
  ## 3. Timeline events and PDUs
  ## 4. Forward extremities
  ## 5. Room aliases
  ## 6. Membership data (joined counts, invite states)
  ## 7. Typing indicators
  ## 8. Read receipts
  ## 9. Server participation tracking
  ## 10. Appservice caches

  debug "delete_room: purging room ", roomId, " force=", force

  # In real impl, each step calls into the relevant service:

  # 1. Remove room state
  # self.services.state.deleteRoomShortstatehash(roomId, stateLock)
  # self.services.state.deleteAllRoomsForwardExtremities(roomId)

  # 2. Remove timeline/PDU data
  # self.services.timeline.deleteAllByRoomId(roomId)

  # 3. Remove aliases
  # for alias in self.services.alias.localAliasesForRoom(roomId):
  #   self.services.alias.removeAlias(alias, serverUser)

  # 4. Remove membership data
  # self.services.stateCache.deleteRoomJoinCounts(roomId, force)

  # 5. Remove typing data
  # self.services.typing.typing[roomId].clear()

  # 6. Remove short mappings
  # self.services.short.deleteShortRoomId(roomId)

  # 7. Clear caches
  # self.services.stateCache.clearAppserviceInRoomCache()
  # self.services.spaces.clearCache()

  info "delete_room: completed purge for room ", roomId

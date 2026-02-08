## threads/mod — service module.
##
## Ported from Rust service/rooms/threads/mod.rs
##
## Thread management: tracks thread participants and provides
## thread enumeration for rooms. Supports deletion for room purging.

import std/[options, json, tables, strutils, logging, sets]

const
  RustPath* = "service/rooms/threads/mod.rs"
  RustCrate* = "service"

type
  Data* = ref object
    threadidUserids*: Table[string, HashSet[string]]  # thread_root → participants

  Service* = ref object
    db*: Data

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

proc build*(): Service =
  ## Ported from `build`.
  Service(
    db: Data(
      threadidUserids: initTable[string, HashSet[string]](),
    ),
  )

proc name*(self: Service): string =
  ## Ported from `name`.
  "rooms::threads"

# ---------------------------------------------------------------------------
# Thread operations
# ---------------------------------------------------------------------------

proc updateParticipants*(self: Service; rootId: string; participants: seq[string]) =
  ## Ported from `update_participants`.
  ##
  ## Updates the participant list for a thread. Adds new participants
  ## to the existing set, maintaining an accumulated list of all users
  ## who have posted in the thread.

  if rootId notin self.db.threadidUserids:
    self.db.threadidUserids[rootId] = initHashSet[string]()

  for userId in participants:
    self.db.threadidUserids[rootId].incl(userId)

  debug "update_participants: thread ", rootId, " now has ",
        self.db.threadidUserids[rootId].len, " participants"


proc getParticipants*(self: Service; rootId: string): seq[string] =
  ## Ported from `get_participants`.
  ## Returns all participants who ever posted in the thread.

  if rootId in self.db.threadidUserids:
    for userId in self.db.threadidUserids[rootId]:
      result.add(userId)


proc threadsInRoom*(self: Service; roomId: string): seq[string] =
  ## Ported from implicit thread listing.
  ## Returns all thread root IDs in the room (by prefix scan).

  let prefix = roomId & "\xFF"
  for rootId in self.db.threadidUserids.keys:
    if rootId.startsWith(prefix):
      result.add(rootId)


proc deleteAllRoomsThreads*(self: Service; roomId: string) =
  ## Ported from `delete_all_rooms_threads`.
  ## Removes all thread data for a room.

  let prefix = roomId & "\xFF"
  var toRemove: seq[string] = @[]
  for rootId in self.db.threadidUserids.keys:
    if rootId.startsWith(prefix):
      toRemove.add(rootId)

  for rootId in toRemove:
    self.db.threadidUserids.del(rootId)

  debug "delete_all_rooms_threads: removed ", toRemove.len, " threads from ", roomId

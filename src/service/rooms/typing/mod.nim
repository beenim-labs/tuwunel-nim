## typing/mod — service module.
##
## Ported from Rust service/rooms/typing/mod.rs
##
## Manages per-room typing indicator state. Tracks which users are typing
## in which rooms with timeout-based expiry, notifies local clients
## and sends federation EDUs to remote servers.

import std/[options, json, tables, strutils, logging, times, locks]

const
  RustPath* = "service/rooms/typing/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    ## Per-room typing state. Maps room_id → (user_id → timeout_millis).
    typing*: Table[string, Table[string, uint64]]
    ## Timestamp of the last typing change per room.
    lastTypingUpdate*: Table[string, uint64]
    ## Global counter for update sequencing.
    typingCounter: uint64
    lock: Lock

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

proc build*(): Service =
  ## Ported from `build`.
  result = Service(
    typing: initTable[string, Table[string, uint64]](),
    lastTypingUpdate: initTable[string, uint64](),
    typingCounter: 0,
  )
  initLock(result.lock)

proc name*(self: Service): string =
  ## Ported from `name`.
  "rooms::typing"

# ---------------------------------------------------------------------------
# Typing add/remove
# ---------------------------------------------------------------------------

proc nextCount(self: Service): uint64 =
  withLock self.lock:
    self.typingCounter += 1
    result = self.typingCounter

proc typingAdd*(self: Service; userId, roomId: string; timeout: uint64) =
  ## Ported from `typing_add`.
  ##
  ## Sets a user as typing until the timeout timestamp is reached
  ## or typingRemove is called.

  debug "typing started ", userId, " in ", roomId, " timeout:", timeout

  # Update typing map
  if roomId notin self.typing:
    self.typing[roomId] = initTable[string, uint64]()
  self.typing[roomId][userId] = timeout

  # Record the update sequence number
  let count = self.nextCount()
  self.lastTypingUpdate[roomId] = count

  # In real impl: send federation EDU if user is local
  # if self.services.globals.userIsLocal(userId):
  #   self.federationSend(roomId, userId, true)


proc typingRemove*(self: Service; userId, roomId: string) =
  ## Ported from `typing_remove`.
  ##
  ## Removes a user from typing before the timeout is reached.

  debug "typing stopped ", userId, " in ", roomId

  if roomId in self.typing:
    self.typing[roomId].del(userId)

  let count = self.nextCount()
  self.lastTypingUpdate[roomId] = count

  # In real impl: send federation EDU if user is local
  # if self.services.globals.userIsLocal(userId):
  #   self.federationSend(roomId, userId, false)


proc waitForUpdate*(self: Service; roomId: string) =
  ## Ported from `wait_for_update`.
  ## Waits for a typing update in the given room.
  ## In real impl: uses broadcast channel receiver.
  discard


proc typingsMaintain*(self: Service; roomId: string) =
  ## Ported from `typings_maintain`.
  ##
  ## Makes sure that typing events with old timestamps get removed.

  let currentTimestamp = epochTime().uint64 * 1000  # millis

  if roomId notin self.typing:
    return

  var removable: seq[string] = @[]
  for userId, timeout in self.typing[roomId]:
    if timeout < currentTimestamp:
      removable.add(userId)

  if removable.len > 0:
    for userId in removable:
      debug "typing timeout ", userId, " in ", roomId
      self.typing[roomId].del(userId)

    let count = self.nextCount()
    self.lastTypingUpdate[roomId] = count

    # In real impl: send federation EDUs for removed local users


proc getLastTypingUpdate*(self: Service; roomId: string): uint64 =
  ## Ported from `last_typing_update`.
  ##
  ## Returns the count of the last typing update in this room.

  self.typingsMaintain(roomId)
  self.lastTypingUpdate.getOrDefault(roomId, 0)


proc typingUsersForUser*(self: Service; roomId, senderUser: string): seq[string] =
  ## Ported from `typing_users_for_user`.
  ##
  ## Returns currently typing users in the room, filtering out users
  ## that the sender has ignored.

  if roomId notin self.typing:
    return @[]

  for userId in self.typing[roomId].keys:
    # In real impl: filter ignored users
    # if not self.services.users.userIsIgnored(userId, senderUser):
    result.add(userId)


proc federationSend*(self: Service; roomId, userId: string; typing: bool) =
  ## Ported from `federation_send`.
  ##
  ## Sends a typing EDU to federated servers in the room.

  # In real impl:
  # 1. Check config.allowOutgoingTyping
  # 2. Create TypingContent EDU
  # 3. Serialize and send via self.services.sending.sendEduRoom(roomId, buf)

  debug "federation_send: typing=", typing, " user=", userId, " room=", roomId

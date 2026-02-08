## read_receipt/data — service module.
##
## Ported from Rust service/rooms/read_receipt/data.rs
##
## Read receipt storage: tracks both public read receipts (m.read)
## and private read markers (m.fully_read). Stores per-user,
## per-room read positions with update counts for sync.

import std/[options, json, tables, strutils, logging]

const
  RustPath* = "service/rooms/read_receipt/data.rs"
  RustCrate* = "service"

type
  PduCount* = uint64

  ReadReceiptData* = ref object
    ## roomuserid_privateread: room+user → private read count
    privateRead*: Table[string, PduCount]
    ## roomuserid_lastprivatereadupdate: room+user → last update count
    lastPrivateReadUpdate*: Table[string, PduCount]
    ## readreceiptid: room+user → receipt event data
    readReceipts*: Table[string, JsonNode]

proc userRoomKey(userId, roomId: string): string =
  userId & "\xFF" & roomId

proc roomUserKey(roomId, userId: string): string =
  roomId & "\xFF" & userId

# ---------------------------------------------------------------------------
# Public read receipts
# ---------------------------------------------------------------------------

proc readreceiptUpdate*(self: ReadReceiptData; userId, roomId: string; event: JsonNode) =
  ## Ported from `readreceipt_update`.
  ##
  ## Stores a read receipt event for a user in a room.
  ## The event contains the receipt type and event ID marker.

  let key = roomUserKey(roomId, userId)
  self.readReceipts[key] = event

  debug "readreceipt_update: ", userId, " in ", roomId


proc readreceiptsForRoom*(self: ReadReceiptData; roomId: string;
                          since: PduCount): seq[tuple[userId: string, event: JsonNode]] =
  ## Returns all read receipts for a room since the given count.
  ## In real impl: this iterates the readreceiptid map filtered by room and since count.

  let prefix = roomId & "\xFF"
  for key, event in self.readReceipts:
    if key.startsWith(prefix):
      let userId = key[prefix.len ..< key.len]
      result.add((userId: userId, event: event))

# ---------------------------------------------------------------------------
# Private read markers
# ---------------------------------------------------------------------------

proc privateReadSet*(self: ReadReceiptData; roomId, userId: string;
                     pduCount: PduCount) =
  ## Ported from `private_read_set`.
  ##
  ## Sets the private read marker position for a user in a room.
  ## This corresponds to m.fully_read account data.

  let key = roomUserKey(roomId, userId)
  self.privateRead[key] = pduCount

  # In real impl: also store the update count for sync
  self.lastPrivateReadUpdate[key] = pduCount

  debug "private_read_set: ", userId, " in ", roomId, " at count ", pduCount


proc privateReadGetCount*(self: ReadReceiptData; roomId, userId: string): Option[PduCount] =
  ## Ported from `private_read_get_count`.
  ## Returns the private read marker position.

  let key = roomUserKey(roomId, userId)
  if key in self.privateRead:
    some(self.privateRead[key])
  else:
    none(PduCount)


proc lastPrivatereadUpdate*(self: ReadReceiptData; userId, roomId: string): Option[PduCount] =
  ## Ported from `last_privateread_update`.
  ## Returns the count of the last private read update (for sync).

  let key = roomUserKey(roomId, userId)
  if key in self.lastPrivateReadUpdate:
    some(self.lastPrivateReadUpdate[key])
  else:
    none(PduCount)

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

proc deleteAllReadReceipts*(self: ReadReceiptData; roomId: string) =
  ## Ported from `delete_all_read_receipts`.
  ## Removes all read receipt data for a room.

  let prefix = roomId & "\xFF"

  var toRemove: seq[string] = @[]
  for key in self.readReceipts.keys:
    if key.startsWith(prefix):
      toRemove.add(key)
  for key in toRemove:
    self.readReceipts.del(key)

  toRemove = @[]
  for key in self.privateRead.keys:
    if key.startsWith(prefix):
      toRemove.add(key)
  for key in toRemove:
    self.privateRead.del(key)
    self.lastPrivateReadUpdate.del(key)

  debug "delete_all_read_receipts: cleaned up room ", roomId

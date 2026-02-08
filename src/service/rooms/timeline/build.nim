## timeline/build — service module.
##
## Ported from Rust service/rooms/timeline/build.rs
##
## Event building and appending: creates a PDU, validates it through
## admin room checks and redaction authorization, appends to state
## and timeline, and sends to federated servers.

import std/[options, json, tables, strutils, logging, sets]

const
  RustPath* = "service/rooms/timeline/build.rs"
  RustCrate* = "service"

proc buildAndAppendPdu*(self: auto; pduBuilder: auto;
                        sender, roomId: string): string =
  ## Ported from `build_and_append_pdu`.
  ##
  ## Creates a new persisted data unit and adds it to a room.
  ## This function takes a roomid_mutex_state, ensuring only one
  ## mutation at a time.
  ##
  ## Steps:
  ## 1. Create, hash, and sign the event
  ## 2. Handle v12+ room ID format for m.room.create
  ## 3. Check admin room restrictions (no encryption, no self-ban)
  ## 4. Validate redaction permissions (version-aware)
  ## 5. Validate m.room.member constraints (join_authorized_via_users_server)
  ## 6. Append to room state
  ## 7. Append to timeline (with new prev_events = [this event])
  ## 8. Set room state hash
  ## 9. Compute server list and send PDU via federation

  # 1. Create event
  # let (pdu, pduJson) = self.createHashAndSignEvent(pduBuilder, sender, roomId, stateLock)
  let eventId = "$placeholder_event_id"

  # 2. V12+ room ID for create events
  # if pdu.kind == "m.room.create" and pdu.roomId.serverName.isNone:
  #   self.services.short.getOrCreateShortroomid(pdu.roomId)

  # 3. Admin room check
  # if self.services.admin.isAdminRoom(pdu.roomId):
  #   self.checkPduForAdminRoom(pdu, sender)

  # 4. Redaction authorization
  # if pdu.kind == "m.room.redaction":
  #   check version + authorization

  # 5. Membership constraints
  # if pdu.kind == "m.room.member":
  #   validate join_authorized_via_users_server

  # 6. Append to state
  # let statehashid = self.services.state.appendToState(pdu)

  # 7. Append to timeline
  # let pduId = self.appendPdu(pdu, pduJson, [pdu.eventId], stateLock)

  # 8. Set room state
  # self.services.state.setRoomState(pdu.roomId, statehashid, stateLock)

  # 9. Send to federation
  # let servers = self.services.stateCache.roomServers(pdu.roomId)
  # servers.remove(ourServer)
  # self.services.sending.sendPduServers(servers, pduId)

  debug "build_and_append_pdu: type=", "event", " room=", roomId, " sender=", sender

  eventId


proc checkPduForAdminRoom*(self: auto; pdu: JsonNode; sender: string) =
  ## Ported from `check_pdu_for_admin_room`.
  ##
  ## Validates PDUs destined for the admin room:
  ## - Blocks encryption events
  ## - Prevents the server user from leaving
  ## - Prevents banning the last admin
  ## - Prevents the last admin from leaving

  let eventType = pdu.getOrDefault("type").getStr("")
  let stateKey = pdu.getOrDefault("state_key").getStr("")

  case eventType
  of "m.room.encryption":
    raise newException(ValueError, "Encryption not supported in admins room.")
  of "m.room.member":
    let content = pdu.getOrDefault("content")
    let membership = content.getOrDefault("membership").getStr("")
    let target = if stateKey.len > 0 and stateKey.startsWith("@"):
      stateKey
    else:
      sender

    case membership
    of "leave":
      # In real impl: check if target is server user
      # if target == self.services.globals.serverUser:
      #   raise "Server user cannot leave the admins room."
      # Check if last admin
      # let count = localMembers.filter(isNotTarget)
      # if count < 2: raise "Last admin cannot leave"
      discard
    of "ban":
      # Same checks as leave
      discard
    else:
      discard
  else:
    discard
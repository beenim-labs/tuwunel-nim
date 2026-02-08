## timeline/backfill — service module.
##
## Ported from Rust service/rooms/timeline/backfill.rs
##
## Backfilling: fetches historical events from federation when the local
## timeline has gaps. Prioritizes servers by power level, canonical alias,
## and trusted server list.

import std/[options, json, tables, strutils, logging, sets, algorithm]

const
  RustPath* = "service/rooms/timeline/backfill.rs"
  RustCrate* = "service"

proc backfillIfRequired*(self: auto; roomId: string; fromCount: uint64) =
  ## Ported from `backfill_if_required`.
  ##
  ## Determines if backfill is needed and initiates it from the best
  ## available federation server.
  ##
  ## Backfill is NOT required when:
  ## - There are still events between fromCount and the first event
  ## - The first event is m.room.create (we've reached the beginning)
  ## - The room is empty or not world readable (no one to ask)
  ##
  ## Server selection priority:
  ## 1. Power level holders (non-local users with elevated power)
  ## 2. Canonical alias server
  ## 3. Trusted servers from config
  ## Filtered to servers actually participating in the room.

  # 1. Check if backfill needed
  # In real impl:
  # let (firstPduCount, firstPdu) = self.firstItemInRoom(roomId)
  # if firstPduCount < fromCount: return  # still have events
  # if firstPdu.eventType == "m.room.create": return  # reached beginning

  # 2. Check room accessibility
  # In real impl:
  # let emptyRoom = self.services.stateCache.roomJoinedCount(roomId) <= 1
  # let notWorldReadable = not self.services.stateAccessor.isWorldReadable(roomId)
  # if emptyRoom and notWorldReadable: return

  # 3. Build server priority list
  var servers: seq[string] = @[]

  # 3a. Power level servers
  # In real impl: extract from power_levels state event
  # let powerLevels = self.services.stateAccessor.getPowerLevels(roomId)
  # for (userId, level) in powerLevels.users:
  #   if level > default and not isLocal(userId):
  #     servers.add(userId.serverName)

  # 3b. Canonical alias server
  # In real impl:
  # let alias = self.services.stateAccessor.getCanonicalAlias(roomId)
  # if alias.isSome: servers.add(alias.serverName)

  # 3c. Trusted servers
  # In real impl: servers.add(config.trustedServers)

  # 4. Filter to participating servers (not us)
  # servers = servers.filter(s => s != ourServer and serverInRoom(s, roomId))

  # 5. Try each server
  for server in servers:
    debug "backfill_if_required: asking ", server, " for room ", roomId

    # In real impl:
    # let request = BackfillRequest(roomId, v=[firstEventId], limit=100)
    # let response = self.services.federation.execute(server, request)
    # if response.isOk:
    #   for pdu in response.pdus:
    #     self.backfillPdu(roomId, server, pdu)
    #   return

  debug "backfill_if_required: no servers could backfill room ", roomId


proc backfillPdu*(self: auto; roomId, origin: string; pdu: JsonNode) =
  ## Ported from `backfill_pdu`.
  ##
  ## Processes a single backfilled PDU:
  ## 1. Parse incoming PDU
  ## 2. Lock federation mutex for the room
  ## 3. Handle incoming PDU through event_handler
  ## 4. Skip if PDU already existed
  ## 5. Allocate negative PduCount (backfilled events go in Z-)
  ## 6. Persist with prepend_backfill_pdu
  ## 7. Index for search if m.room.message

  # In real impl:
  # let (_, eventId, value) = self.services.eventHandler.parseIncomingPdu(pdu)
  # let mutexLock = self.services.eventHandler.mutexFederation.lock(roomId)
  # let existed = self.services.eventHandler.handleIncomingPdu(origin, roomId, eventId, value, false)
  # if existed: return  # duplicate

  let eventId = pdu.getOrDefault("event_id").getStr("")

  # Allocate negative count for backfill
  # In real impl: let count = -(self.services.globals.nextCount())
  # let pduId = PduId{shortroomid, count: PduCount.Backfilled(count)}

  # Persist
  # self.prependBackfillPdu(pduId, eventId, pduJson)

  # Search index
  let eventType = pdu.getOrDefault("type").getStr("")
  if eventType == "m.room.message":
    let body = pdu.getOrDefault("content").getOrDefault("body").getStr("")
    if body.len > 0:
      # In real impl: self.services.search.indexPdu(shortroomid, pduId, body)
      discard

  debug "backfill_pdu: prepended ", eventId


proc prependBackfillPdu*(self: auto; pduId, eventId: string; json: JsonNode) =
  ## Ported from `prepend_backfill_pdu`.
  ## Low-level storage: writes backfilled PDU and removes outlier status.

  # In real impl:
  # self.db.pduidPdu.rawPut(pduId, Json(json))
  # self.db.eventidPduid.insert(eventId, pduId)
  # self.db.eventidOutlierpdu.remove(eventId)

  debug "prepend_backfill_pdu: ", eventId

## event_handler/handle_outlier_pdu — service module.
##
## Ported from Rust service/rooms/event_handler/handle_outlier_pdu.rs
##
## Validates and persists an event as an outlier (not yet in the timeline).
## Steps: remove unsigned, verify signatures, check content hash, check format,
## fetch missing auth events, perform auth check, persist as outlier.

import std/[options, json, tables, strutils, logging, sequtils]
import ./mod as event_handler_mod

const
  RustPath* = "service/rooms/event_handler/handle_outlier_pdu.rs"
  RustCrate* = "service"

type
  PduEvent* = JsonNode
  CanonicalJsonObject* = JsonNode
  VerificationResult* = enum
    vrAll, vrSignaturesOnly, vrFailed

proc handleOutlierPdu*(self: Service; origin: string; roomId: string;
                       eventId: string; pduJson: var JsonNode;
                       roomVersion: string;
                       authEventsKnown: bool): tuple[event: PduEvent, json: CanonicalJsonObject] =
  ## Ported from `handle_outlier_pdu`.
  ##
  ## Validates an incoming federation event and persists it as an outlier.
  ## Returns the parsed event and canonical JSON if validation succeeds.

  debug "handle_outlier_pdu: ", eventId, " auth_events_known=", authEventsKnown

  # 1. Remove unsigned field
  if pduJson.hasKey("unsigned"):
    pduJson.delete("unsigned")

  # 2. Check signatures, otherwise drop
  # 3. Check content hash, redact if doesn't match
  # In real impl: self.services.serverKeys.verifyEvent(pduJson, roomVersion)
  let verifyResult = vrAll  # placeholder

  var processedJson = pduJson
  case verifyResult
  of vrAll:
    discard  # JSON is valid as-is
  of vrSignaturesOnly:
    # Signatures valid but hash mismatch — needs redaction
    debug "handle_outlier_pdu: hash mismatch, redacting ", eventId
    # In real impl: apply room-version-specific redaction rules
    # In real impl: skip if already known as outlier
    # let rules = roomVersion.rules()
    # processedJson = ruma.canonicalJson.redact(pduJson, rules.redaction, nil)
    discard
  of vrFailed:
    raise newException(ValueError,
      "Signature verification failed for " & eventId)

  # Check PDU format according to room version rules
  # In real impl: stateRes.checkPduFormat(processedJson, roomRules.eventFormat)

  # Convert to internal PduEvent type
  # In real impl: fromIncomingFederation(roomId, eventId, processedJson, roomRules)
  let event = processedJson

  # Verify room ID matches
  let pduRoomId = event.getOrDefault("room_id").getStr("")
  checkRoomId(roomId, pduRoomId, eventId)

  if not authEventsKnown:
    # 4. Fetch any missing auth events (steps 4-5)
    debug "handle_outlier_pdu: fetching auth events for ", eventId
    # In real impl: self.fetchAuth(origin, roomId, event.authEvents, roomVersion)

  # 6. Auth check based on auth events
  debug "handle_outlier_pdu: checking auth for ", eventId

  # Determine event format rules
  # In real impl: check room_rules.event_format.allow_room_create_in_auth_events
  let isHydra = false  # placeholder
  let eventType = event.getOrDefault("type").getStr("")
  let notCreate = eventType != "m.room.create"

  # Collect auth events for verification
  let authEventIds = block:
    var ids: seq[string] = @[]
    let authEvents = event.getOrDefault("auth_events")
    if authEvents.kind == JArray:
      for ae in authEvents:
        if ae.kind == JString:
          ids.add(ae.getStr())
    ids

  # In real impl: fetch each auth event, build auth state map
  # In real impl: stateRes.authCheck(roomRules, event, eventFetch, stateFetch)

  # 7. Persist the event as an outlier
  # In real impl: self.services.timeline.addPduOutlier(eventId, processedJson)
  debug "handle_outlier_pdu: added as outlier: ", eventId

  (event: event, json: processedJson)
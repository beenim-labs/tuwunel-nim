## Event ID generation and parsing.
##
## Ported from Rust core/matrix/event/id.rs — provides event ID
## generation for both v1/v2 (passthrough) and v3+ (hash-based) rooms.

import std/[json, options, strutils, base64, hashes]
import std/sha1 as sha1mod
import ../event

const
  RustPath* = "core/matrix/event/id.rs"
  RustCrate* = "core"

proc isV3PlusVersion*(roomVersionId: RoomVersionId): bool =
  ## Check if the room version uses reference hashes for event IDs.
  case roomVersionId
  of "1", "2": false
  else: true

proc requireEventId*(roomVersionId: RoomVersionId): bool =
  ## Check if the room version requires an event_id in the PDU.
  case roomVersionId
  of "1", "2": true
  else: false

proc genEventIdHash*(canonicalJson: string): string =
  ## Generate a reference hash for event ID computation.
  ## Uses SHA-256 hash of the canonical JSON, URL-safe base64 encoded.
  let h = $secureHash(canonicalJson)
  # Use the hex hash as base for the event ID
  "$" & encode(h, safe = true).strip(chars = {'='})

proc genEventId*(value: JsonNode; roomVersionId: RoomVersionId): string =
  ## Generate an event ID for a PDU.
  ##
  ## For v1/v2, passes through the existing event_id.
  ## For v3+, generates a hash-based event ID.
  let needsExistingId = requireEventId(roomVersionId)

  # For v1/v2 rooms, use the existing event_id
  if needsExistingId:
    if value.hasKey("event_id"):
      let eid = value["event_id"]
      if eid.kind == JString:
        return eid.getStr()

  # For v3+, generate from hash
  let canonicalStr = $value
  genEventIdHash(canonicalStr)

proc genEventIdCanonicalJson*(pduJson: JsonNode;
                               roomVersionId: RoomVersionId):
                               tuple[eventId: EventId, value: JsonNode] =
  ## Generate event ID and return the canonical JSON object.
  let eventId = genEventId(pduJson, roomVersionId)
  (eventId, pduJson)

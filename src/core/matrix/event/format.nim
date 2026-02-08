## Event format conversion.
##
## Ported from Rust core/matrix/event/format.rs — provides conversion
## between various Matrix event serialization formats (sync, timeline,
## state, stripped, hierarchy).

import std/[json, options]
import ../event

const
  RustPath* = "core/matrix/event/format.rs"
  RustCrate* = "core"

type
  ## Event format kind determines which fields are included in serialization.
  EventFormat* = enum
    efSync           ## Sync format: no room_id
    efTimeline       ## Timeline format: includes room_id
    efState          ## State format: includes room_id, no redacts
    efSyncState      ## Sync state format: no room_id, no redacts
    efStripped       ## Stripped: sender, type, content, state_key only
    efHierarchyChild ## Hierarchy space child: origin_server_ts, no event_id

proc formatEvent*(event: Event; format: EventFormat): JsonNode =
  ## Convert an event to the specified format.
  case format
  of efSync:
    result = event.toSyncFormat()
  of efTimeline:
    result = event.toTimelineFormat()
  of efState:
    result = %*{
      "content": event.getContentAsValue(),
      "event_id": event.eventId,
      "origin_server_ts": event.originServerTs,
      "room_id": event.roomId,
      "sender": event.sender,
      "type": event.eventType,
    }
    if event.stateKey.isSome:
      result["state_key"] = %event.stateKey.get()
    if event.unsigned.isSome:
      result["unsigned"] = event.unsigned.get()
  of efSyncState:
    result = %*{
      "content": event.getContentAsValue(),
      "event_id": event.eventId,
      "origin_server_ts": event.originServerTs,
      "sender": event.sender,
      "type": event.eventType,
    }
    if event.stateKey.isSome:
      result["state_key"] = %event.stateKey.get()
    if event.unsigned.isSome:
      result["unsigned"] = event.unsigned.get()
  of efStripped:
    result = event.toStrippedFormat()
  of efHierarchyChild:
    result = %*{
      "content": event.getContentAsValue(),
      "origin_server_ts": event.originServerTs,
      "sender": event.sender,
      "type": event.eventType,
    }
    if event.stateKey.isSome:
      result["state_key"] = %event.stateKey.get()

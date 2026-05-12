const
  RustPath* = "api/client/sync/v3.rs"
  RustCrate* = "api"

import std/json

proc emptyRooms*(): JsonNode =
  %*{
    "join": {},
    "invite": {},
    "leave": {}
  }

proc joinedRoomPayload*(
  timeline: openArray[JsonNode] = [];
  state: openArray[JsonNode] = [];
  accountData: openArray[JsonNode] = [];
  ephemeral: openArray[JsonNode] = [];
  prevBatch = "";
  limited = false;
  highlightCount = 0;
  notificationCount = 0
): JsonNode =
  result = %*{
    "timeline": {
      "events": [],
      "limited": limited
    },
    "state": {
      "events": []
    },
    "account_data": {
      "events": []
    },
    "ephemeral": {
      "events": []
    },
    "unread_notifications": {
      "highlight_count": highlightCount,
      "notification_count": notificationCount
    }
  }
  if prevBatch.len > 0:
    result["timeline"]["prev_batch"] = %prevBatch
  for event in timeline:
    result["timeline"]["events"].add(if event.isNil: newJObject() else: event.copy())
  for event in state:
    result["state"]["events"].add(if event.isNil: newJObject() else: event.copy())
  for event in accountData:
    result["account_data"]["events"].add(if event.isNil: newJObject() else: event.copy())
  for event in ephemeral:
    result["ephemeral"]["events"].add(if event.isNil: newJObject() else: event.copy())

proc syncV3Response*(
  nextBatch: string;
  joinedRooms: JsonNode = nil;
  invitedRooms: JsonNode = nil;
  leftRooms: JsonNode = nil;
  accountData: openArray[JsonNode] = [];
  presence: openArray[JsonNode] = [];
  toDevice: openArray[JsonNode] = [];
  deviceOneTimeKeysCount: JsonNode = nil;
  deviceUnusedFallbackKeyTypes: openArray[string] = []
): JsonNode =
  result = %*{
    "next_batch": nextBatch,
    "rooms": emptyRooms(),
    "account_data": {"events": []},
    "presence": {"events": []},
    "to_device": {"events": []},
    "device_one_time_keys_count": if deviceOneTimeKeysCount.isNil: newJObject() else: deviceOneTimeKeysCount.copy(),
    "device_unused_fallback_key_types": []
  }
  if not joinedRooms.isNil:
    result["rooms"]["join"] = joinedRooms.copy()
  if not invitedRooms.isNil:
    result["rooms"]["invite"] = invitedRooms.copy()
  if not leftRooms.isNil:
    result["rooms"]["leave"] = leftRooms.copy()
  for event in accountData:
    result["account_data"]["events"].add(if event.isNil: newJObject() else: event.copy())
  for event in presence:
    result["presence"]["events"].add(if event.isNil: newJObject() else: event.copy())
  for event in toDevice:
    result["to_device"]["events"].add(if event.isNil: newJObject() else: event.copy())
  for keyType in deviceUnusedFallbackKeyTypes:
    result["device_unused_fallback_key_types"].add(%keyType)

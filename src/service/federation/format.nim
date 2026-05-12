const
  RustPath* = "service/federation/format.rs"
  RustCrate* = "service"

import std/json

import core/matrix/pdu/format as pdu_format

proc formatPduInto*(
  pduJson: JsonNode;
  roomVersion = "";
  queriedRoomVersion = "";
): JsonNode =
  result = if pduJson.isNil: newJObject() else: pduJson.copy()
  let effectiveRoomVersion =
    if roomVersion.len > 0:
      roomVersion
    else:
      queriedRoomVersion

  if effectiveRoomVersion.len > 0:
    result = pdu_format.intoOutgoingFederation(result, effectiveRoomVersion)
  elif result.kind == JObject:
    result.delete("event_id")

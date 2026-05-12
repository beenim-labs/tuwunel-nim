const
  RustPath* = "core/matrix/state_res/events.rs"
  RustCrate* = "core"

import std/json

import core/matrix/state_res/json_helpers
import core/matrix/state_res/events/[
  create,
  join_rules,
  member,
  power_levels,
  third_party_invite,
]

export
  create,
  join_rules,
  member,
  power_levels,
  third_party_invite

proc isPowerEvent*(event: JsonNode): bool =
  if event.isNil or event.kind != JObject:
    return false

  let eventType = event.jsonField("type").getStr("")
  let stateKey = event.jsonField("state_key").getStr("")
  case eventType
  of "m.room.power_levels", "m.room.join_rules", "m.room.create":
    stateKey == ""
  of "m.room.member":
    let parsed = roomMemberEvent(event).membership()
    if not parsed.ok or parsed.state notin {msLeave, msBan}:
      return false
    event.jsonField("sender").getStr("") != stateKey
  else:
    false

import std/[json, unittest]

import api/server/backfill as server_backfill_api
import api/server/event as server_event_api
import api/server/event_auth as server_event_auth_api
import api/server/get_missing_events as server_missing_api
import api/server/state as server_state_api
import api/server/state_ids as server_state_ids_api

proc pdu(id: string; pos: int): JsonNode =
  %*{
    "event_id": id,
    "room_id": "!room:localhost",
    "sender": "@alice:localhost",
    "type": "m.room.message",
    "origin_server_ts": pos,
    "content": {"body": id}
  }

suite "Federation event API helpers":
  test "single event payload preserves Rust federation response shape":
    let payload = server_event_api.eventPayload("localhost", 123'i64, pdu("$a", 1))
    check payload.ok
    check payload.payload["origin"].getStr("") == "localhost"
    check payload.payload["origin_server_ts"].getInt() == 123
    check payload.payload["pdu"]["event_id"].getStr("") == "$a"
    check not server_event_api.eventPayload("", 123'i64, pdu("$a", 1)).ok

  test "state and state_ids payloads use auth chain and state event arrays":
    let statePayload = server_state_api.roomStatePayload(@[], @[pdu("$create", 1), pdu("$member", 2)])
    check statePayload.ok
    check statePayload.payload["auth_chain"].len == 0
    check statePayload.payload["pdus"].len == 2

    let idsPayload = server_state_ids_api.roomStateIdsPayload(@["$auth"], @["$create", "$member"])
    check idsPayload.ok
    check idsPayload.payload["auth_chain_ids"][0].getStr("") == "$auth"
    check idsPayload.payload["pdu_ids"][1].getStr("") == "$member"

  test "backfill selects events before the newest matching v boundary":
    let timeline = @[
      server_backfill_api.backfillEvent("$a", 1, pdu("$a", 1)),
      server_backfill_api.backfillEvent("$b", 2, pdu("$b", 2)),
      server_backfill_api.backfillEvent("$c", 3, pdu("$c", 3)),
      server_backfill_api.backfillEvent("$d", 4, pdu("$d", 4)),
    ]
    let selected = server_backfill_api.selectBackfillEvents(timeline, @["$b", "$d"], 10)
    check selected.len == 3
    check selected[0].eventId == "$c"
    check selected[1].eventId == "$b"
    check selected[2].eventId == "$a"

    let payload = server_backfill_api.backfillPayload("localhost", 456'i64, timeline, @["$d"], 2)
    check payload.ok
    check payload.payload["origin"].getStr("") == "localhost"
    check payload.payload["pdus"].len == 2
    check payload.payload["pdus"][0]["event_id"].getStr("") == "$c"

  test "missing events supports Rust-style prev_event walk and positional fallback":
    let timeline = @[
      server_missing_api.missingEvent("$a", 1, pdu("$a", 1)),
      server_missing_api.missingEvent("$b", 2, pdu("$b", 2), @["$a"]),
      server_missing_api.missingEvent("$c", 3, pdu("$c", 3), @["$b"]),
      server_missing_api.missingEvent("$d", 4, pdu("$d", 4), @["$c"]),
    ]
    let selected = server_missing_api.selectMissingEvents(timeline, @["$b"], @["$d"], 10)
    check selected.len == 2
    check selected[0].eventId == "$d"
    check selected[1].eventId == "$c"

    let positional = server_missing_api.missingEventsPayloadByPosition(
      timeline,
      %*{
        "earliest_events": ["$b"],
        "latest_events": ["$d"],
        "limit": 10
      }
    )
    check positional.ok
    check positional.payload["events"].len == 1
    check positional.payload["events"][0]["event_id"].getStr("") == "$c"

  test "event auth payload returns auth chain array":
    let payload = server_event_auth_api.eventAuthPayload(%*[pdu("$auth", 1)])
    check payload.ok
    check payload.payload["auth_chain"][0]["event_id"].getStr("") == "$auth"
    check not server_event_auth_api.eventAuthPayload(newJObject()).ok

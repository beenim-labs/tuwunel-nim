import std/[json, options, strutils, unittest]

import core/matrix/event as matrix_event
import core/matrix/event/filter as event_filter
import core/matrix/event/redact as event_redact
import core/matrix/event/relation as event_relation
import core/matrix/event/state_key as event_state_key
import core/matrix/pdu as matrix_pdu
import core/matrix/pdu/count as pdu_count
import core/matrix/pdu/format as pdu_format
import core/matrix/pdu/raw_id as pdu_raw_id
import core/matrix/pdu/tests as pdu_embedded_tests
import core/matrix/pdu/unsigned as pdu_unsigned

proc sampleEvent(): JsonNode =
  %*{
    "event_id": "$event",
    "room_id": "!room:localhost",
    "sender": "@alice:localhost",
    "type": "m.room.message",
    "origin_server_ts": 1234,
    "content": {
      "body": "hello",
      "msgtype": "m.text",
      "m.relates_to": {
        "rel_type": "m.thread",
        "event_id": "$root"
      }
    },
    "unsigned": {
      "transaction_id": "txn",
      "redacted_because": {}
    },
    "auth_events": ["$auth"],
    "prev_events": ["$prev"]
  }

suite "Matrix event and PDU helpers":
  test "MatrixEvent roundtrips JSON and exposes filter relation and unsigned helpers":
    let parsed = matrix_event.fromJson(sampleEvent())
    check parsed.ok
    check parsed.event.eventId == "$event"
    check parsed.event.prevEvents == @["$prev"]
    check matrix_event.toJson(parsed.event)["content"]["body"].getStr("") == "hello"

    check event_relation.relationTypeEqual(sampleEvent(), "m.thread")
    check matrix_event.containsUnsignedProperty(sampleEvent(), "transaction_id", JString)
    check matrix_event.getContentProperty(sampleEvent(), "body").value.getStr("") == "hello"
    check matrix_event.isRedacted(sampleEvent())

    let filter = event_filter.RoomEventFilter(
      rooms: @["!room:localhost"],
      senders: @["@alice:localhost"],
      types: @["m.room.message"],
      urlFilter: some(false),
    )
    check filter.matchesEvent(sampleEvent())

  test "redaction compatibility copies top-level redacts into content":
    let redaction = %*{
      "event_id": "$redaction",
      "room_id": "!room:localhost",
      "sender": "@mod:localhost",
      "type": "m.room.redaction",
      "origin_server_ts": 1235,
      "redacts": "$event",
      "content": {"reason": "cleanup"}
    }
    let copied = event_redact.copyRedactsForClient(redaction)
    check copied.redacts == "$event"
    check copied.content["redacts"].getStr("") == "$event"
    check event_redact.redactsId(redaction, false) == "$event"
    check event_redact.roomVersionContentFieldRedacts("11")

  test "event ids and hashes are canonical and deterministic":
    let eventA = %*{"b": 2, "a": 1}
    let eventB = %*{"a": 1, "b": 2}
    let idA = matrix_event.genEventId(eventA, "11")
    let idB = matrix_event.genEventId(eventB, "11")
    check idA.ok
    check idA.eventId == idB.eventId
    check idA.eventId.startsWith("$")
    check idA.eventId.len == 44

    let oldRoom = matrix_event.genEventId(%*{"event_id": "$legacy:localhost"}, "1")
    check oldRoom.ok
    check oldRoom.eventId == "$legacy:localhost"

    let hashes = matrix_pdu.eventHashes(eventA)
    check hashes.ok
    check hashes.hashes.sha256.len == matrix_pdu.Sha256Base64Len

  test "state key ordering follows Rust tuple ordering":
    let a = event_state_key.typeStateKey("m.room.member", "@a:localhost")
    let b = event_state_key.typeStateKey("m.room.name", "")
    check event_state_key.cmp(a, b) < 0
    check event_state_key.rcmp(a, b) > 0
    check matrix_event.withStateKey("m.room.topic", "") == ("m.room.topic", "")

  test "PDU count parse arithmetic and raw id encoding match Rust layout":
    check pdu_embedded_tests.normalParseOk()
    check pdu_embedded_tests.backfilledParseOk()

    let normal = pdu_count.parsePduCount("987654")
    check normal.ok
    check normal.count.kind == pckNormal
    check $normal.count == "987654"

    let backfilled = pdu_count.parsePduCount("-987654")
    check backfilled.ok
    check backfilled.count.kind == pckBackfilled
    check $backfilled.count == "-987654"

    let rawNormal = pdu_raw_id.rawId(matrix_pdu.pduId(7'u64, normal.count))
    check rawNormal.asBytes().len == pdu_raw_id.RawIdNormalLen
    check rawNormal.toPduId().shortRoomId == 7'u64
    check rawNormal.toPduId().count.intoSigned() == 987654

    let rawBackfilled = pdu_raw_id.rawId(matrix_pdu.pduId(7'u64, backfilled.count))
    check rawBackfilled.asBytes().len == pdu_raw_id.RawIdBackfilledLen
    check rawBackfilled.isBackfilled()
    check rawBackfilled.toPduId().count.intoSigned() == -987654
    check rawNormal.isRoomEq(rawBackfilled)

  test "PDU federation formatting unsigned helpers and builder preserve Matrix shape":
    var pdu = sampleEvent()
    let outgoing = pdu_format.intoOutgoingFederation(pdu, "11")
    check not outgoing.hasKey("event_id")
    check not outgoing["unsigned"].hasKey("transaction_id")

    let incoming = pdu_format.fromIncomingFederation(
      "!room:localhost",
      "$generated",
      %*{"type": "m.room.create", "content": {}, "auth_events": [["$a", {}]]},
      "11",
    )
    check incoming["event_id"].getStr("") == "$generated"
    check incoming["room_id"].getStr("") == "!room:localhost"

    pdu_unsigned.removeTransactionId(pdu)
    check not pdu["unsigned"].hasKey("transaction_id")
    pdu_unsigned.addAge(pdu, 2000)
    check pdu["unsigned"]["age"].getInt() == 766
    pdu_unsigned.addRelation(pdu, "m.thread", %*{"event_id": "$root"})
    check pdu["unsigned"]["m.relations"]["m.thread"]["event_id"].getStr("") == "$root"

    let builder = matrix_pdu.stateBuilder(
      "m.room.member",
      "@alice:localhost",
      %*{"membership": "join"},
    ).withTimestamp(1234)
    check builder.eventType == "m.room.member"
    check builder.stateKey.get() == "@alice:localhost"
    check builder.timestamp.get() == 1234

    let parsedPdu = matrix_pdu.fromJson(sampleEvent())
    check parsedPdu.ok
    check matrix_pdu.toJson(parsedPdu.pdu)["prev_events"][0].getStr("") == "$prev"

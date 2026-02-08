## Test suite for core Matrix event and PDU types.
##
## Validates event construction, JSON round-trip, format conversions,
## content extraction, filtering, redaction, and PDU builder/count types.

import unittest
import std/[json, options]
import ../src/core/matrix/event as event_mod
import ../src/core/matrix/event/content as content_mod
import ../src/core/matrix/event/filter as filter_mod
import ../src/core/matrix/event/redact as redact_mod
import ../src/core/matrix/event/state_key as state_key_mod
import ../src/core/matrix/event/relation as relation_mod
import ../src/core/matrix/pdu/builder as builder_mod
import ../src/core/matrix/pdu/count as count_mod
import ../src/core/matrix/pdu/hashes as hashes_mod
import ../src/core/info/room_version as room_version_mod

suite "Matrix Event Types":

  test "Event construction with required fields":
    let event = newEvent(
      eventId = "$abc123",
      roomId = "!room:example.com",
      sender = "@alice:example.com",
      eventType = "m.room.message",
      content = %*{"body": "hello", "msgtype": "m.text"},
    )
    check event.eventId == "$abc123"
    check event.roomId == "!room:example.com"
    check event.sender == "@alice:example.com"
    check event.eventType == "m.room.message"
    check event.stateKey.isNone

  test "Event with state key":
    let event = newEvent(
      eventId = "$state1",
      roomId = "!room:example.com",
      sender = "@alice:example.com",
      eventType = "m.room.member",
      content = %*{"membership": "join"},
      stateKey = some("@alice:example.com"),
    )
    check event.stateKey.isSome
    check event.stateKey.get() == "@alice:example.com"

  test "isTypeAndStateKey":
    let event = newEvent(
      eventId = "$e1",
      roomId = "!r:e.com",
      sender = "@a:e.com",
      eventType = "m.room.member",
      content = %*{"membership": "join"},
      stateKey = some("@b:e.com"),
    )
    check event.isTypeAndStateKey("m.room.member", "@b:e.com")
    check not event.isTypeAndStateKey("m.room.member", "@c:e.com")
    check not event.isTypeAndStateKey("m.room.name", "@b:e.com")

  test "JSON round-trip":
    let original = newEvent(
      eventId = "$roundtrip",
      roomId = "!r:e.com",
      sender = "@a:e.com",
      eventType = "m.room.message",
      content = %*{"body": "test", "msgtype": "m.text"},
      originServerTs = 1000000,
    )
    original.prevEvents = @["$prev1", "$prev2"]
    original.authEvents = @["$auth1"]

    let j = original.toJson()
    let restored = fromJson(j)

    check restored.eventId == "$roundtrip"
    check restored.roomId == "!r:e.com"
    check restored.sender == "@a:e.com"
    check restored.eventType == "m.room.message"
    check restored.originServerTs == 1000000
    check restored.prevEvents.len == 2
    check restored.authEvents.len == 1

  test "Sync format omits room_id":
    let event = newEvent(
      eventId = "$sync",
      roomId = "!r:e.com",
      sender = "@a:e.com",
      eventType = "m.room.message",
      content = %*{"body": "hi"},
    )
    let sync = event.toSyncFormat()
    check not sync.hasKey("room_id")
    check sync.hasKey("event_id")
    check sync.hasKey("sender")

  test "Timeline format includes room_id":
    let event = newEvent(
      eventId = "$tl",
      roomId = "!r:e.com",
      sender = "@a:e.com",
      eventType = "m.room.message",
      content = %*{"body": "hi"},
    )
    let tl = event.toTimelineFormat()
    check tl.hasKey("room_id")
    check tl["room_id"].getStr() == "!r:e.com"

  test "Stripped format is minimal":
    let event = newEvent(
      eventId = "$stripped",
      roomId = "!r:e.com",
      sender = "@a:e.com",
      eventType = "m.room.name",
      content = %*{"name": "Test Room"},
      stateKey = some(""),
    )
    let stripped = event.toStrippedFormat()
    check stripped.hasKey("sender")
    check stripped.hasKey("type")
    check stripped.hasKey("content")
    check stripped.hasKey("state_key")
    check not stripped.hasKey("event_id")
    check not stripped.hasKey("room_id")

suite "Event Content Extraction":

  test "getMembership":
    let event = newEvent(
      eventId = "$m1",
      roomId = "!r:e.com",
      sender = "@a:e.com",
      eventType = "m.room.member",
      content = %*{"membership": "join"},
      stateKey = some("@a:e.com"),
    )
    check getMembership(event) == "join"

  test "getRoomName":
    let event = newEvent(
      eventId = "$n1",
      roomId = "!r:e.com",
      sender = "@a:e.com",
      eventType = "m.room.name",
      content = %*{"name": "My Room"},
      stateKey = some(""),
    )
    check getRoomName(event) == "My Room"

  test "getContentString":
    let event = newEvent(
      eventId = "$c1",
      roomId = "!r:e.com",
      sender = "@a:e.com",
      eventType = "m.room.message",
      content = %*{"body": "hello", "msgtype": "m.text"},
    )
    check getContentString(event, "body") == some("hello")
    check getContentString(event, "missing").isNone

suite "Event Filtering":

  test "Empty filter matches everything":
    let event = newEvent(
      eventId = "$f1",
      roomId = "!r:e.com",
      sender = "@a:e.com",
      eventType = "m.room.message",
      content = %*{},
    )
    let filter = newRoomEventFilter()
    check matches(event, filter)

  test "Filter by sender - not_senders excludes":
    let event = newEvent(
      eventId = "$f2",
      roomId = "!r:e.com",
      sender = "@banned:e.com",
      eventType = "m.room.message",
      content = %*{},
    )
    var filter = newRoomEventFilter()
    filter.notSenders = @["@banned:e.com"]
    check not matches(event, filter)

  test "Filter by type - only specified types":
    let event = newEvent(
      eventId = "$f3",
      roomId = "!r:e.com",
      sender = "@a:e.com",
      eventType = "m.room.message",
      content = %*{},
    )
    var filter = newRoomEventFilter()
    filter.types = some(@["m.room.member"])
    check not matches(event, filter)

    filter.types = some(@["m.room.message"])
    check matches(event, filter)

suite "Event Redaction":

  test "isRedacted with redacted_because":
    let event = newEvent(
      eventId = "$red1",
      roomId = "!r:e.com",
      sender = "@a:e.com",
      eventType = "m.room.message",
      content = %*{"body": "deleted"},
    )
    event.unsigned = some(%*{"redacted_because": %*{"event_id": "$redaction"}})
    check isEventRedacted(event)

  test "isRedacted without redacted_because":
    let event = newEvent(
      eventId = "$red2",
      roomId = "!r:e.com",
      sender = "@a:e.com",
      eventType = "m.room.message",
      content = %*{"body": "visible"},
    )
    check not isEventRedacted(event)

  test "getRedactsId for v10 room":
    let event = newEvent(
      eventId = "$redact1",
      roomId = "!r:e.com",
      sender = "@a:e.com",
      eventType = "m.room.redaction",
      content = %*{},
    )
    event.redacts = some("$target")
    check getRedactsId(event, "10") == some("$target")

  test "getRedactsId for v11 room uses content":
    let event = newEvent(
      eventId = "$redact2",
      roomId = "!r:e.com",
      sender = "@a:e.com",
      eventType = "m.room.redaction",
      content = %*{"redacts": "$target_v11"},
    )
    check getRedactsId(event, "11") == some("$target_v11")

suite "PDU Builder":

  test "Default builder":
    let builder = newPduBuilder()
    check builder.eventType == "m.room.message"
    check builder.stateKey.isNone
    check builder.redacts.isNone

  test "State event builder":
    let builder = stateEvent("", "m.room.topic",
      %*{"topic": "Discussion"})
    check builder.eventType == "m.room.topic"
    check builder.stateKey == some("")

  test "Timeline event builder":
    let builder = timelineEvent("m.room.message",
      %*{"body": "hi", "msgtype": "m.text"})
    check builder.eventType == "m.room.message"
    check builder.stateKey.isNone

  test "Builder JSON serialization":
    let builder = stateEvent("@user:e.com", "m.room.member",
      %*{"membership": "join"})
    let j = builder.toJson()
    check j["type"].getStr() == "m.room.member"
    check j["state_key"].getStr() == "@user:e.com"

suite "PDU Count":

  test "Normal count":
    let c = normalCount(42)
    check c.kind == ckNormal
    check c.intoSigned() == 42
    check $c == "42"

  test "Backfilled count":
    let c = backfilledCount(-10)
    check c.kind == ckBackfilled
    check c.intoSigned() == -10
    check $c == "-10"

  test "Count comparison":
    let a = normalCount(5)
    let b = normalCount(10)
    let c = backfilledCount(-3)
    check a < b
    check c < a
    check not (b < a)

  test "Count arithmetic":
    let c = normalCount(5)
    check c.checkedAdd(3).intoSigned() == 8
    check c.checkedSub(2).intoSigned() == 3
    check c.saturatingAdd(uint64.high).intoUnsigned() == uint64.high

  test "Count from/to signed":
    check fromSigned(10).kind == ckNormal
    check fromSigned(-5).kind == ckBackfilled
    check fromSigned(0).kind == ckBackfilled

  test "parseCount":
    check parseCount("42").intoSigned() == 42
    check parseCount("-7").intoSigned() == -7

suite "Room Version Support":

  test "Stable versions":
    check isStableRoomVersion("6")
    check isStableRoomVersion("11")
    check not isStableRoomVersion("2")

  test "Unstable versions":
    check isUnstableRoomVersion("2")
    check isUnstableRoomVersion("5")
    check not isUnstableRoomVersion("6")

  test "Supported versions":
    check isSupportedRoomVersion("6")
    check isSupportedRoomVersion("2", allowUnstable = true)
    check not isSupportedRoomVersion("2", allowUnstable = false)

  test "Available room versions list":
    let versions = availableRoomVersions()
    check versions.len > 0

suite "Event Hashes":

  test "Empty hashes":
    let h = newEventHashes()
    check h.isEmpty()

  test "Non-empty hashes":
    let h = newEventHashes("abc123")
    check not h.isEmpty()
    check h.sha256 == "abc123"

suite "Event Relations":

  test "getRelationType for annotation":
    let event = newEvent(
      eventId = "$rel1",
      roomId = "!r:e.com",
      sender = "@a:e.com",
      eventType = "m.reaction",
      content = %*{
        "m.relates_to": {
          "rel_type": "m.annotation",
          "event_id": "$target",
          "key": "👍",
        }
      },
    )
    let relType = getRelationType(event)
    check relType.isSome
    check relType.get() == rtAnnotation

  test "getRelatesTo":
    let event = newEvent(
      eventId = "$rel2",
      roomId = "!r:e.com",
      sender = "@a:e.com",
      eventType = "m.room.message",
      content = %*{
        "m.relates_to": {
          "rel_type": "m.thread",
          "event_id": "$thread_root",
        }
      },
    )
    check getRelatesTo(event) == some("$thread_root")
    check hasRelationType(event, rtThread)

  test "No relation":
    let event = newEvent(
      eventId = "$rel3",
      roomId = "!r:e.com",
      sender = "@a:e.com",
      eventType = "m.room.message",
      content = %*{"body": "plain message"},
    )
    check getRelationType(event).isNone
    check getRelatesTo(event).isNone

import std/[json, strutils, unittest]

import api/client/account_data as client_account_data
import api/client/filter as client_filter
import api/client/read_marker as client_read_marker
import api/client/tag as client_tag

suite "Client appstate API helpers":
  test "account data helpers preserve event shape, tombstones and forbidden types":
    let event = client_account_data.accountDataEventJson("m.direct", %*{"@alice:localhost": ["!room:localhost"]})
    check event["type"].getStr == "m.direct"
    check event["content"]["@alice:localhost"][0].getStr == "!room:localhost"

    check not client_account_data.isEmptyObjectJson(%*{"x": 1})
    check client_account_data.isEmptyObjectJson(newJObject())
    check client_account_data.isEmptyAccountDataEvent(%*{"type": "m.tag", "content": {}})
    check client_account_data.accountDataGetPolicy(newJObject()).errcode == "M_NOT_FOUND"

    check client_account_data.accountDataSetPolicy("m.fully_read").errcode == "M_BAD_JSON"
    check client_account_data.accountDataSetPolicy("m.push_rules").message.contains("push rules")
    check client_account_data.accountDataSetPolicy("m.direct").ok
    check client_account_data.accountDataAccessPolicy("@alice:localhost", "@bob:localhost").errcode == "M_FORBIDDEN"
    check client_account_data.accountDataAccessPolicy("@alice:localhost", "@bob:localhost", isAppservice = true).ok
    check client_account_data.accountDataWriteResponse().len == 0

  test "filter helpers build stable ids, responses and access policy":
    check client_filter.filterKey("@alice:localhost", "abcd") == "@alice:localhost" & "\x1f" & "abcd"
    check client_filter.createFilterResponse("abcd")["filter_id"].getStr == "abcd"

    let filterPayload = client_filter.filterPayload(%*{"room": {"timeline": {"limit": 10}}})
    check filterPayload["room"]["timeline"]["limit"].getInt == 10
    check client_filter.filterNotFound().errcode == "M_NOT_FOUND"
    check client_filter.filterAccessPolicy("@alice:localhost", "@bob:localhost").errcode == "M_FORBIDDEN"
    check client_filter.filterAccessPolicy("@alice:localhost", "@bob:localhost", isAppservice = true).ok

  test "tag helpers normalize m.tag content and update/delete individual tags":
    let emptyTags = client_tag.tagsPayload()
    check emptyTags["tags"].kind == JObject
    check emptyTags["tags"].len == 0

    let withTag = client_tag.updateTagPayload(emptyTags, "u.work", %*{"order": 0.25})
    check withTag["tags"]["u.work"]["order"].getFloat == 0.25

    let favorite = client_tag.updateTagPayload(withTag, "m.favourite", newJObject())
    check favorite["tags"].hasKey("u.work")
    check favorite["tags"].hasKey("m.favourite")

    let deleted = client_tag.deleteTagPayload(favorite, "u.work")
    check not deleted["tags"].hasKey("u.work")
    check deleted["tags"].hasKey("m.favourite")

    check client_tag.tagAccessPolicy("@alice:localhost", "@bob:localhost", joinedRoom = true).errcode == "M_FORBIDDEN"
    check client_tag.tagAccessPolicy("@alice:localhost", "@alice:localhost", joinedRoom = false).errcode == "M_FORBIDDEN"
    check client_tag.tagAccessPolicy("@alice:localhost", "@bob:localhost", joinedRoom = true, isAppservice = true).ok
    check client_tag.tagWriteResponse().len == 0

  test "read-marker helpers build fully-read and receipt event content":
    check client_read_marker.fullyReadContent("$event")["event_id"].getStr == "$event"

    let receiptContent = client_read_marker.receiptContent(
      "$event",
      "m.read",
      "@alice:localhost",
      ts = 1234'i64,
      threadId = "$thread",
    )
    check receiptContent["$event"]["m.read"]["@alice:localhost"]["ts"].getInt == 1234
    check receiptContent["$event"]["m.read"]["@alice:localhost"]["thread_id"].getStr == "$thread"

    let receiptEvent = client_read_marker.receiptEvent("!room:localhost", "$event", "m.read", "@alice:localhost", ts = 1234'i64)
    check receiptEvent["type"].getStr == "m.receipt"
    check receiptEvent["room_id"].getStr == "!room:localhost"

    check client_read_marker.receiptPolicy("m.fully_read", threadId = "$thread").errcode == "M_INVALID_PARAM"
    check client_read_marker.receiptPolicy("m.unknown").message == "Unsupported receipt type."
    check client_read_marker.receiptPolicy("m.read", eventRelatedToThread = false).message == "event_id is not related to the given thread_id"
    check client_read_marker.receiptPolicy("m.read").ok

    let markers = client_read_marker.readMarkersFromBody(%*{
      "m.fully_read": "$fully",
      "read_receipt": "$public",
      "private_read_receipt": "$private"
    })
    check markers.fullyRead == "$fully"
    check markers.publicRead == "$public"
    check markers.privateRead == "$private"
    check client_read_marker.readMarkerBodyPolicy(markers).ok
    check client_read_marker.readMarkerBodyPolicy(("", "", "")).errcode == "M_BAD_JSON"
    check client_read_marker.readMarkerResponse().len == 0

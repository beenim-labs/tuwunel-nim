import std/[json, tables, unittest]

import api/client/events as client_events
import api/client/presence as client_presence
import api/client/profile as client_profile
import api/client/to_device as client_to_device
import api/client/typing as client_typing

suite "Client profile, presence and visible-state API helpers":
  test "profile helpers normalize canonical fields and custom profile data":
    var custom = initTable[string, JsonNode]()
    custom["displayname"] = %"shadow"
    custom["us.cloke.msc4175.tz"] = %"Legacy/Zone"
    custom["com.example.status"] = %"coding"

    var data = client_profile.profileData(
      "Alice",
      "mxc://localhost/avatar",
      "LKO2?U%2Tw=w]~RBVZRi};RPxuwH",
      "Europe/Stockholm",
      custom,
    )
    let full = client_profile.profilePayload(data)
    check full["displayname"].getStr == "Alice"
    check full["avatar_url"].getStr == "mxc://localhost/avatar"
    check full["blurhash"].getStr == "LKO2?U%2Tw=w]~RBVZRi};RPxuwH"
    check full["m.tz"].getStr == "Europe/Stockholm"
    check full["com.example.status"].getStr == "coding"
    check not full.hasKey("us.cloke.msc4175.tz")

    let avatar = client_profile.profileFieldPayload(data, "avatar_url")
    check avatar.ok
    check avatar.payload["avatar_url"].getStr == "mxc://localhost/avatar"
    check avatar.payload["blurhash"].getStr == "LKO2?U%2Tw=w]~RBVZRi};RPxuwH"

    let legacyTz = client_profile.profileFieldPayload(data, "us.cloke.msc4175.tz")
    check legacyTz.ok
    check legacyTz.payload["us.cloke.msc4175.tz"].getStr == "Europe/Stockholm"

    client_profile.setProfileField(data, "m.tz", %*{"m.tz": "UTC"})
    check client_profile.profileFieldPayload(data, "m.tz").payload["m.tz"].getStr == "UTC"
    client_profile.deleteProfileField(data, "com.example.status")
    check not client_profile.profileFieldPayload(data, "com.example.status").ok

    check client_profile.profileAccessPolicy("@alice:localhost", "@bob:localhost").errcode == "M_FORBIDDEN"
    check client_profile.profileAccessPolicy("@alice:localhost", "@bob:localhost", isAppservice = true).ok
    check client_profile.profileWriteResponse().len == 0

  test "presence helpers match Rust visibility and response elision rules":
    check client_presence.isValidPresenceValue("online")
    check client_presence.isValidPresenceValue("busy")
    check not client_presence.isValidPresenceValue("away")

    check client_presence.presenceSetPolicy(false, true).errcode == "M_FORBIDDEN"
    check client_presence.presenceSetPolicy(true, false).errcode == "M_INVALID_PARAM"
    check client_presence.presenceSetPolicy(true, false, isAppservice = true).ok
    check client_presence.presenceGetPolicy(true, visible = false, found = true).errcode == "M_NOT_FOUND"

    let active = client_presence.presenceResponse("online", currentlyActive = true, lastActiveAgo = 5000)
    check active["presence"].getStr == "online"
    check active["currently_active"].getBool
    check not active.hasKey("last_active_ago")
    check not active.hasKey("status_msg")

    let idle = client_presence.presenceResponse("unavailable", currentlyActive = false, lastActiveAgo = 5000, statusMsg = "available")
    check idle["last_active_ago"].getInt == 5000
    check idle["status_msg"].getStr == "available"

    let event = client_presence.presenceEvent(
      "@alice:localhost",
      "online",
      currentlyActive = true,
      lastActiveAgo = 0,
      displayName = "Alice",
      avatarUrl = "mxc://localhost/avatar",
    )
    check event["type"].getStr == "m.presence"
    check event["sender"].getStr == "@alice:localhost"
    check event["content"]["displayname"].getStr == "Alice"
    check event["content"]["avatar_url"].getStr == "mxc://localhost/avatar"
    check client_presence.presenceWriteResponse().len == 0

  test "typing helpers clamp timeout, enforce sender policy and emit ephemeral event shape":
    check client_typing.typingPolicy(senderMatchesTarget = false, senderJoinedRoom = true).errcode == "M_FORBIDDEN"
    check client_typing.typingPolicy(senderMatchesTarget = true, senderJoinedRoom = false).message == "You are not in this room."
    check client_typing.typingPolicy(senderMatchesTarget = false, senderJoinedRoom = true, isAppservice = true).ok

    check client_typing.clampTypingTimeout(500, minMs = 15000, maxMs = 45000) == 15000
    check client_typing.clampTypingTimeout(60000, minMs = 15000, maxMs = 45000) == 45000
    check client_typing.clampTypingTimeout(30000, minMs = 15000, maxMs = 45000) == 30000

    let event = client_typing.typingEvent(["@alice:localhost", "@bob:localhost"])
    check event["type"].getStr == "m.typing"
    check event["content"]["user_ids"][0].getStr == "@alice:localhost"
    check event["content"]["user_ids"][1].getStr == "@bob:localhost"
    check client_typing.typingResponse().len == 0

  test "to-device helpers validate body shape, txn ids and event responses":
    check client_to_device.toDeviceTxnKey("@alice:localhost", "DEV1", "txn1") ==
      "@alice:localhost" & "\x1f" & "DEV1" & "\x1f" & "txn1"
    check client_to_device.toDevicePolicy("", "txn1", %*{"messages": {}}).errcode == "M_INVALID_PARAM"
    check client_to_device.toDevicePolicy("m.dummy", "", %*{"messages": {}}).errcode == "M_INVALID_PARAM"
    check client_to_device.toDevicePolicy("m.dummy", "txn1", %*{"not_messages": {}}).errcode == "M_BAD_JSON"

    let body = %*{
      "messages": {
        "@alice:localhost": {
          "*": {"body": "all"},
          "DEV1": {"body": "one"}
        }
      }
    }
    check client_to_device.toDevicePolicy("m.room.encrypted", "txn1", body).ok
    let extracted = client_to_device.extractToDeviceMessages(body)
    check extracted.ok
    check extracted.events.len == 2
    check client_to_device.targetDeviceIds("*", ["DEV2", "DEV1"]) == @["DEV1", "DEV2"]

    let event = client_to_device.toDeviceEvent("m.room.encrypted", "@alice:localhost", %*{"ciphertext": "abc"})
    check event["type"].getStr == "m.room.encrypted"
    check event["sender"].getStr == "@alice:localhost"
    check event["content"]["ciphertext"].getStr == "abc"
    check client_to_device.toDeviceResponse().len == 0

  test "deprecated events helpers cap limit, normalize timeout and preserve stream shape":
    check client_events.normalizeEventsLimit(0) == 1
    check client_events.normalizeEventsLimit(500) == client_events.EventLimit
    check client_events.normalizeEventsTimeout(-1, defaultMs = 30000, minMs = 1000, maxMs = 60000) == 30000
    check client_events.normalizeEventsTimeout(0, defaultMs = 30000, minMs = 1000, maxMs = 60000) == 1000
    check client_events.eventsAccessPolicy(false).errcode == "M_FORBIDDEN"

    let response = client_events.eventsResponse([%*{"event_id": "$one"}], start = "s1", ending = "s2")
    check response["chunk"][0]["event_id"].getStr == "$one"
    check response["start"].getStr == "s1"
    check response["end"].getStr == "s2"

    let fromArray = client_events.eventsResponse(%*[%*{"event_id": "$two"}], start = "s2", ending = "s3")
    check fromArray["chunk"][0]["event_id"].getStr == "$two"
    check client_events.emptyEventsResponse("s3", "s4")["chunk"].len == 0

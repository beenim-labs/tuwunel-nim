import std/[json, unittest]

import api/server/invite as server_invite_api
import api/server/make_join as server_make_join_api
import api/server/make_knock as server_make_knock_api
import api/server/make_leave as server_make_leave_api
import api/server/send as server_send_api
import api/server/send_join as server_send_join_api
import api/server/send_knock as server_send_knock_api
import api/server/send_leave as server_send_leave_api

proc memberEvent(membership: string): JsonNode =
  %*{
    "event_id": "$member",
    "room_id": "!room:localhost",
    "sender": "@remote:example.org",
    "type": "m.room.member",
    "state_key": "@remote:example.org",
    "origin_server_ts": 123,
    "content": {"membership": membership}
  }

suite "Federation membership API helpers":
  test "make membership routes return room version and template event":
    let joinPayload = server_make_join_api.makeJoinPayload("11", memberEvent("join"))
    check joinPayload.ok
    check joinPayload.payload["room_version"].getStr("") == "11"
    check joinPayload.payload["event"]["content"]["membership"].getStr("") == "join"

    let leavePayload = server_make_leave_api.makeLeavePayload("11", memberEvent("leave"))
    check leavePayload.ok
    check leavePayload.payload["event"]["content"]["membership"].getStr("") == "leave"

    let knockPayload = server_make_knock_api.makeKnockPayload("11", memberEvent("knock"))
    check knockPayload.ok
    check knockPayload.payload["event"]["content"]["membership"].getStr("") == "knock"

  test "send membership routes preserve Rust response fields":
    let sendJoin = server_send_join_api.sendJoinPayload(
      %*[memberEvent("join")],
      newJArray(),
      memberEvent("join"),
      false,
      "localhost",
    )
    check sendJoin.ok
    check sendJoin.payload["state"].len == 1
    check sendJoin.payload["auth_chain"].len == 0
    check sendJoin.payload["event"]["content"]["membership"].getStr("") == "join"
    check sendJoin.payload["members_omitted"].getBool(true) == false
    check sendJoin.payload["origin"].getStr("") == "localhost"

    let sendKnock = server_send_knock_api.sendKnockPayload(%*[memberEvent("knock")])
    check sendKnock.ok
    check sendKnock.payload["knock_room_state"].len == 1

    let invite = server_invite_api.invitePayload(memberEvent("invite"))
    check invite.ok
    check invite.payload["event"]["content"]["membership"].getStr("") == "invite"

    check server_send_leave_api.sendLeavePayload().kind == JObject

  test "send transaction wraps PDU result map":
    let tx = server_send_api.sendTransactionPayload(%*{
      "$event": {}
    })
    check tx.ok
    check tx.payload["pdus"]["$event"].kind == JObject
    check not server_send_api.sendTransactionPayload(newJArray()).ok

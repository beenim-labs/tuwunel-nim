import std/[json, strutils, unittest]

import api/client/backup as client_backup
import api/client/dehydrated_device as client_dehydrated
import api/client/device as client_device
import api/client/push as client_push
import api/client/report as client_report

suite "Client device, push, backup and report API helpers":
  test "device helpers preserve metadata payloads and validate update/delete bodies":
    let device = client_device.DeviceData(
      deviceId: "DEV1",
      displayName: "Alice phone",
      lastSeenIp: "127.0.0.1",
      lastSeenTs: 1234,
    )
    let payload = client_device.devicePayload(device)
    check payload["device_id"].getStr == "DEV1"
    check payload["display_name"].getStr == "Alice phone"
    check payload["last_seen_ip"].getStr == "127.0.0.1"
    check payload["last_seen_ts"].getInt == 1234

    let devices = client_device.devicesPayload([device])
    check devices["devices"][0]["device_id"].getStr == "DEV1"

    let update = client_device.deviceUpdateFromBody(%*{"display_name": "New name"})
    check update.ok
    check update.updateDisplayName
    check update.displayName == "New name"
    check client_device.deviceUpdateFromBody(%*{"display_name": 10}).errcode == "M_BAD_JSON"

    let deleteBody = client_device.deleteDevicesFromBody(%*{"devices": ["DEV1", "", "DEV2"]})
    check deleteBody.ok
    check deleteBody.deviceIds == @["DEV1", "DEV2"]
    check client_device.deleteDevicesFromBody(%*{"devices": "DEV1"}).message == "devices must be an array."
    check client_device.deviceWriteResponse().len == 0

  test "push helpers normalize pushers and push rule payloads":
    check client_push.pusherKey("@alice:localhost", "app", "key") ==
      "@alice:localhost" & "\x1f" & "app" & "\x1f" & "key"
    check client_push.pushRuleKey("@alice:localhost", "global", "override", ".m.rule.master").contains("\x1f")
    check client_push.isPushRuleKind("underride")
    check not client_push.isPushRuleKind("unknown")

    let pusher = client_push.pusherFromBody(%*{
      "app_id": "chat",
      "pushkey": "abc",
      "data": {"url": "https://push.example"}
    })
    check pusher.ok
    check not pusher.delete
    check pusher.pusher["kind"].getStr == "http"
    check pusher.pusher["lang"].getStr == "en"
    check pusher.pusher["data"]["url"].getStr == "https://push.example"
    check client_push.pusherFromBody(%*{"app_id": "chat"}).errcode == "M_MISSING_PARAM"
    check client_push.pusherFromBody(%*{"app_id": "chat", "pushkey": "abc", "kind": nil}).delete

    let emptyRules = client_push.emptyPushRulesPayload()
    check emptyRules["global"]["override"].len == 0
    let contentRule = client_push.normalizePushRule(%*{"actions": ["notify"]}, "contains-alice", "content")
    check contentRule["rule_id"].getStr == "contains-alice"
    check contentRule["enabled"].getBool
    check contentRule["pattern"].getStr == ""

    let enabled = client_push.pushRuleAttrPayload(contentRule, "enabled")
    check enabled.ok
    check enabled.payload["enabled"].getBool
    let updated = client_push.updatePushRuleAttr(contentRule, "contains-alice", "content", "actions", %*{"actions": ["dont_notify"]})
    check updated.ok
    check updated.payload["actions"][0].getStr == "dont_notify"
    check client_push.updatePushRuleAttr(contentRule, "contains-alice", "content", "enabled", %*{"enabled": "yes"}).errcode == "M_BAD_JSON"

    check client_push.notificationLimit(0) == 1
    check client_push.notificationLimit(500) == 100
    check client_push.notificationOnlyHighlight("highlight")
    check client_push.pushWriteResponse().len == 0

  test "backup helpers build version, rooms and best-session mutation payloads":
    let version = client_backup.backupVersionPayload(
      "1",
      "m.megolm_backup.v1.curve25519-aes-sha2",
      %*{"public_key": "abc"},
      count = 2,
      etag = "9",
    )
    check version["version"].getStr == "1"
    check version["auth_data"]["public_key"].getStr == "abc"
    check version["count"].getInt == 2
    check version["etag"].getStr == "9"

    let records = @[
      client_backup.BackupSessionData(roomId: "!b:localhost", sessionId: "s2", sessionData: %*{"first_message_index": 2}),
      client_backup.BackupSessionData(roomId: "!a:localhost", sessionId: "s1", sessionData: %*{"first_message_index": 1}),
    ]
    let rooms = client_backup.backupRoomsPayload(records)
    check rooms["rooms"]["!a:localhost"]["sessions"]["s1"]["first_message_index"].getInt == 1
    let sessions = client_backup.backupRoomSessionsPayload(records, "!b:localhost")
    check sessions["sessions"]["s2"]["first_message_index"].getInt == 2

    let missing = client_backup.betterBackupSessionCandidate(%*{}, %*{"is_verified": true})
    check not missing.ok
    check missing.message.contains("first_message_index")
    let replace = client_backup.betterBackupSessionCandidate(
      %*{"is_verified": false, "first_message_index": 10, "forwarded_count": 5},
      %*{"is_verified": true, "first_message_index": 10, "forwarded_count": 5},
    )
    check replace.ok
    check replace.replace
    check client_backup.backupMutationPayload(2, "9")["etag"].getStr == "9"
    check client_backup.backupVersionCreateResponse("3")["version"].getStr == "3"
    check client_backup.backupMetadataPolicy(%*{"algorithm": "x"}).ok
    check client_backup.backupWriteResponse().len == 0

  test "dehydrated device helpers preserve device data and event response shape":
    let parsed = client_dehydrated.deviceDataFromBody(%*{
      "device_id": "DEHYD1",
      "device_data": {"algorithm": "m.dehydrated_device.v2"}
    })
    check parsed.ok
    check parsed.device.deviceId == "DEHYD1"
    let payload = client_dehydrated.dehydratedDevicePayload(parsed.device)
    check payload["device_id"].getStr == "DEHYD1"
    check payload["device_data"]["algorithm"].getStr == "m.dehydrated_device.v2"
    check client_dehydrated.putDehydratedDeviceResponse("DEHYD1")["device_id"].getStr == "DEHYD1"
    check client_dehydrated.deleteDehydratedDeviceResponse().len == 0

    let events = client_dehydrated.dehydratedEventsResponse([%*{"type": "m.dummy"}], nextBatch = "10")
    check events["events"][0]["type"].getStr == "m.dummy"
    check events["next_batch"].getStr == "10"
    check client_dehydrated.dehydratedEventsResponse()["events"].len == 0
    check client_dehydrated.dehydratedNotFoundMessage() == "No dehydrated device is stored."

  test "report helpers enforce reason and target validation":
    let report = client_report.parseReportBody(%*{"reason": "spam", "score": -50})
    check report.ok
    check report.report.reason == "spam"
    check report.report.score == -50
    check client_report.parseReportBody(%*{"reason": 10}).errcode == "M_BAD_JSON"
    check client_report.parseReportBody(%*{"reason": repeat("x", client_report.ReasonMaxLen + 1)}).errcode == "M_INVALID_PARAM"

    check client_report.reportTargetPolicy(foundRoom = false).message == "Room not found."
    check client_report.reportTargetPolicy(foundRoom = true, eventExists = false).message.contains("Event ID")
    check client_report.reportTargetPolicy(foundRoom = true, reporterInRoom = false).message.contains("not in the room")
    check client_report.reportTargetPolicy(foundRoom = true).ok
    check client_report.reportResponse().len == 0

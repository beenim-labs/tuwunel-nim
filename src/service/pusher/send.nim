const
  RustPath* = "service/pusher/send.rs"
  RustCrate* = "service"

import std/[json, strutils]

import service/pusher/request

type
  PushNoticePolicyResult* = tuple[ok: bool, notify: bool, message: string]

proc hasNotifyAction*(actions: openArray[string]): bool =
  for action in actions:
    if action == "notify":
      return true
  false

proc malformedNotifyActions*(actions: openArray[string]): bool =
  var seen = 0
  for action in actions:
    if action in ["notify", "dont_notify", "coalesce"]:
      inc seen
  seen > 1

proc pushNoticePolicy*(actions: openArray[string]; pushEverything = false): PushNoticePolicyResult =
  if malformedNotifyActions(actions):
    return (
      false,
      false,
      "Malformed pushrule contains more than one of these actions: [\"dont_notify\", \"notify\", \"coalesce\"]",
    )
  (true, pushEverything or hasNotifyAction(actions), "")

proc notificationPriority*(eventType: string; tweaks: openArray[string]): string =
  if eventType == "m.room.encrypted":
    return "high"
  for tweak in tweaks:
    if tweak.startsWith("highlight") or tweak.startsWith("sound"):
      return "high"
  "low"

proc badgeCountDisabled*(data: JsonNode): bool =
  not data.isNil and data.kind == JObject and
    (data.hasKey("org.matrix.msc4076.disable_badge_count") or data.hasKey("disable_badge_count"))

proc notificationPayload*(
  unread: uint64;
  pusher: Pusher;
  event: JsonNode;
  tweaks: openArray[string] = [];
): JsonNode =
  let eventIdOnly = pusher.format == "event_id_only"
  var deviceData = if pusher.data.isNil: newJObject() else: pusher.data.copy()
  if pusher.format.len > 0:
    deviceData["format"] = %pusher.format

  var device = %*{
    "app_id": pusher.appId,
    "pushkey": pusher.pushkey,
    "data": deviceData,
  }
  if not eventIdOnly:
    device["tweaks"] = %tweaks

  result = %*{
    "notification": {
      "devices": [device],
      "event_id": event{"event_id"}.getStr(""),
      "room_id": event{"room_id"}.getStr(""),
    }
  }

  if not badgeCountDisabled(pusher.data):
    result["notification"]["counts"] = %*{"unread": unread, "missed_calls": 0}

  if not eventIdOnly:
    let eventType = event{"type"}.getStr("")
    result["notification"]["prio"] = %notificationPriority(eventType, tweaks)
    result["notification"]["sender"] = %(event{"sender"}.getStr(""))
    result["notification"]["type"] = %eventType
    result["notification"]["content"] = if event{"content"}.isNil: newJObject() else: event{"content"}.copy()
    if eventType == "m.room.member":
      result["notification"]["user_is_target"] = %(event{"state_key"}.getStr("") == event{"sender"}.getStr(""))

proc sendNoticePolicy*(pusher: Pusher): PusherPolicyResult =
  if pusher.kind == pkHttp:
    return validatePusher(pusher)
  (true, "", "")

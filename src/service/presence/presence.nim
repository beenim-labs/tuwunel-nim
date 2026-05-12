const
  RustPath* = "service/presence/presence.rs"
  RustCrate* = "service"

import std/json

import service/presence/aggregate

type
  Presence* = object
    state*: string
    currentlyActive*: bool
    lastActiveTs*: uint64
    hasStatusMsg*: bool
    statusMsg*: string

  PresenceParseResult* = tuple[ok: bool, presence: Presence, err: string]

proc saturatingSub(a, b: uint64): uint64 =
  if b > a: 0'u64 else: a - b

proc newPresence*(
  state: string;
  currentlyActive: bool;
  lastActiveTs: uint64;
  statusMsg = "";
  hasStatusMsg = false;
): Presence =
  Presence(
    state: if state.len == 0: PresenceOffline else: state,
    currentlyActive: currentlyActive,
    lastActiveTs: lastActiveTs,
    hasStatusMsg: hasStatusMsg and statusMsg.len > 0,
    statusMsg: if hasStatusMsg: statusMsg else: "",
  )

proc toJson*(presence: Presence): JsonNode =
  result = %*{
    "state": presence.state,
    "currently_active": presence.currentlyActive,
    "last_active_ts": presence.lastActiveTs,
  }
  if presence.hasStatusMsg:
    result["status_msg"] = %presence.statusMsg

proc fromJson*(node: JsonNode): PresenceParseResult =
  if node.isNil or node.kind != JObject:
    return (false, Presence(), "Invalid presence data in database")
  let state = node{"state"}.getStr(PresenceOffline)
  let lastActiveTs = uint64(max(node{"last_active_ts"}.getBiggestInt(0), 0))
  (true, newPresence(
    state,
    node{"currently_active"}.getBool(false),
    lastActiveTs,
    node{"status_msg"}.getStr(""),
    not node{"status_msg"}.isNil,
  ), "")

proc fromJsonBytes*(bytes: string): PresenceParseResult =
  try:
    fromJson(parseJson(bytes))
  except JsonParsingError:
    (false, Presence(), "Invalid presence data in database")

proc toPresenceEvent*(
  presence: Presence;
  userId: string;
  nowMs: uint64;
  avatarUrl = "";
  displayName = "";
): JsonNode =
  let lastActiveAgo = saturatingSub(nowMs, presence.lastActiveTs)
  result = %*{
    "sender": userId,
    "content": {
      "presence": presence.state,
      "currently_active": presence.currentlyActive,
      "last_active_ago": lastActiveAgo,
    },
  }
  if presence.hasStatusMsg:
    result["content"]["status_msg"] = %presence.statusMsg
  if avatarUrl.len > 0:
    result["content"]["avatar_url"] = %avatarUrl
  if displayName.len > 0:
    result["content"]["displayname"] = %displayName

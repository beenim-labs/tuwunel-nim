const
  RustPath* = "api/client/sync/v5/rooms.rs"
  RustCrate* = "api"

import std/[json, options]

import api/client/sync/v5/selector

type
  UnreadNotifications* = object
    highlightCount*: int
    notificationCount*: int

  SyncRoomInput* = object
    roomId*: string
    initial*: bool
    lists*: seq[string]
    membership*: Option[string]
    name*: string
    avatar*: string
    isDm*: Option[bool]
    heroes*: seq[string]
    requiredState*: seq[JsonNode]
    inviteState*: seq[JsonNode]
    prevBatch*: string
    numLive*: Option[int]
    limited*: bool
    timeline*: seq[JsonNode]
    bumpStamp*: uint64
    joinedCount*: Option[int]
    invitedCount*: Option[int]
    unreadNotifications*: UnreadNotifications

proc syncRoomInput*(roomId: string): SyncRoomInput =
  SyncRoomInput(
    roomId: roomId,
    membership: none(string),
    isDm: none(bool),
    numLive: none(int),
    joinedCount: none(int),
    invitedCount: none(int),
  )

proc jsonArray(nodes: openArray[JsonNode]): JsonNode =
  result = newJArray()
  for node in nodes:
    result.add(if node.isNil: newJObject() else: node.copy())

proc stringArray(values: openArray[string]): JsonNode =
  result = newJArray()
  for value in values:
    result.add(%value)

proc roomPayload*(room: SyncRoomInput): JsonNode =
  result = %*{
    "initial": room.initial,
    "lists": room.lists,
    "required_state": jsonArray(room.requiredState),
    "invite_state": jsonArray(room.inviteState),
    "limited": room.limited,
    "timeline": jsonArray(room.timeline),
    "bump_stamp": room.bumpStamp,
    "unread_notifications": {
      "highlight_count": room.unreadNotifications.highlightCount,
      "notification_count": room.unreadNotifications.notificationCount
    }
  }
  if room.membership.isSome:
    result["membership"] = %room.membership.get()
  if room.name.len > 0:
    result["name"] = %room.name
  if room.avatar.len > 0:
    result["avatar"] = %room.avatar
  if room.isDm.isSome:
    result["is_dm"] = %room.isDm.get()
  if room.heroes.len > 0:
    result["heroes"] = stringArray(room.heroes)
  if room.prevBatch.len > 0:
    result["prev_batch"] = %room.prevBatch
  if room.numLive.isSome:
    result["num_live"] = %room.numLive.get()
  if room.joinedCount.isSome:
    result["joined_count"] = %room.joinedCount.get()
  if room.invitedCount.isSome:
    result["invited_count"] = %room.invitedCount.get()

proc roomsPayload*(rooms: openArray[SyncRoomInput]): JsonNode =
  result = newJObject()
  for room in rooms:
    result[room.roomId] = roomPayload(room)

proc inputFromWindowRoom*(
  room: WindowRoom;
  timeline: openArray[JsonNode] = [];
  requiredState: openArray[JsonNode] = [];
  name = "";
  prevBatch = "";
): SyncRoomInput =
  SyncRoomInput(
    roomId: room.roomId,
    initial: true,
    lists: room.lists,
    membership: room.membership,
    name: name,
    requiredState: @requiredState,
    prevBatch: prevBatch,
    numLive: some(timeline.len),
    timeline: @timeline,
    bumpStamp: room.lastCount,
  )

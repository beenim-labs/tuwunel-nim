const
  RustPath* = "service/sync/watch.rs"
  RustCrate* = "service"

import std/[algorithm, strutils, tables]

type
  WatchKind* = enum
    wkPrefix,
    wkRawPrefix,
    wkTyping,
    wkShutdown

  WatchTarget* = object
    kind*: WatchKind
    mapName*: string
    prefix*: string

  SyncWatch* = object
    userId*: string
    deviceId*: string
    rooms*: seq[string]
    targets*: seq[WatchTarget]

const
  UserWatchMaps* = [
    "userroomid_joined",
    "userroomid_invitestate",
    "userroomid_leftstate",
    "userroomid_knockedstate",
    "userroomid_notificationcount",
    "userroomid_highlightcount",
    "roomusertype_roomuserdataid",
    "keychangeid_userid",
    "userid_lastonetimekeyupdate",
    "roomuserdataid_accountdata",
  ]

  RoomWatchMaps* = [
    "roomuserid_lastnotificationread",
    "keychangeid_userid",
    "roomusertype_roomuserdataid",
    "pduid_pdu",
    "readreceiptid_readreceipt",
    "typing",
  ]

proc joinedKey(parts: openArray[string]): string =
  result = ""
  for idx, part in parts:
    if idx > 0:
      result.add('\0')
    result.add(part)

proc target*(kind: WatchKind; mapName, prefix: string): WatchTarget =
  WatchTarget(kind: kind, mapName: mapName, prefix: prefix)

proc userWatchTargets*(userId, deviceId: string): seq[WatchTarget] =
  result = @[
    target(wkRawPrefix, "userroomid_joined", userId),
    target(wkRawPrefix, "userroomid_invitestate", userId),
    target(wkRawPrefix, "userroomid_leftstate", userId),
    target(wkRawPrefix, "userroomid_knockedstate", userId),
    target(wkRawPrefix, "userroomid_notificationcount", userId),
    target(wkRawPrefix, "userroomid_highlightcount", userId),
    target(wkPrefix, "roomusertype_roomuserdataid", joinedKey(["", userId])),
    target(wkRawPrefix, "keychangeid_userid", userId),
    target(wkRawPrefix, "userid_lastonetimekeyupdate", userId),
    target(wkPrefix, "roomuserdataid_accountdata", joinedKey(["", userId])),
  ]
  if deviceId.len > 0:
    result.add(target(wkPrefix, "todeviceid_events", joinedKey([userId, deviceId])))

proc roomWatchTargets*(
  userId, roomId: string;
  shortRoomIds: Table[string, string]
): seq[WatchTarget] =
  let shortRoomId = shortRoomIds.getOrDefault(roomId, roomId)
  @[
    target(wkPrefix, "roomuserid_lastnotificationread", joinedKey([roomId, userId])),
    target(wkPrefix, "keychangeid_userid", roomId),
    target(wkPrefix, "roomusertype_roomuserdataid", joinedKey([roomId, userId])),
    target(wkPrefix, "pduid_pdu", shortRoomId),
    target(wkPrefix, "readreceiptid_readreceipt", roomId),
    target(wkTyping, "typing", roomId),
  ]

proc registerSyncWatch*(
  userId, deviceId: string;
  rooms: openArray[string];
  shortRoomIds: Table[string, string] = initTable[string, string]();
): SyncWatch =
  result = SyncWatch(userId: userId, deviceId: deviceId, rooms: @rooms, targets: @[])
  result.targets.add(userWatchTargets(userId, deviceId))
  var sortedRooms = @rooms
  sortedRooms.sort(system.cmp[string])
  for roomId in sortedRooms:
    result.targets.add(roomWatchTargets(userId, roomId, shortRoomIds))
  result.targets.add(target(wkShutdown, "server", "shutdown"))

proc hasTarget*(watch: SyncWatch; mapName, prefix: string; kind = wkPrefix): bool =
  for item in watch.targets:
    if item.kind == kind and item.mapName == mapName and item.prefix == prefix:
      return true
  false

proc firstMatchingTarget*(
  watch: SyncWatch;
  mapName, changedKey: string;
): tuple[ok: bool, target: WatchTarget] =
  for item in watch.targets:
    if item.kind in {wkPrefix, wkRawPrefix} and item.mapName == mapName and changedKey.startsWith(item.prefix):
      return (true, item)
  (false, WatchTarget())

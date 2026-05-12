const
  RustPath* = "api/client/backup.rs"
  RustCrate* = "api"

import std/[algorithm, json]

type
  BackupPolicyResult* = tuple[ok: bool, errcode: string, message: string]

  BackupSessionData* = object
    roomId*: string
    sessionId*: string
    sessionData*: JsonNode

proc backupVersionPayload*(
  version, algorithm: string;
  authData: JsonNode;
  count: int;
  etag: string;
): JsonNode =
  %*{
    "version": version,
    "algorithm": algorithm,
    "auth_data": if authData.isNil: newJObject() else: authData.copy(),
    "count": count,
    "etag": etag,
  }

proc backupRoomsPayload*(records: openArray[BackupSessionData]; roomFilter = ""): JsonNode =
  var sorted: seq[BackupSessionData] = @[]
  for record in records:
    if roomFilter.len == 0 or record.roomId == roomFilter:
      sorted.add(record)
  sorted.sort(proc(a, b: BackupSessionData): int =
    let roomCmp = cmp(a.roomId, b.roomId)
    if roomCmp != 0: roomCmp else: cmp(a.sessionId, b.sessionId)
  )
  var rooms = newJObject()
  for record in sorted:
    if not rooms.hasKey(record.roomId):
      rooms[record.roomId] = %*{"sessions": newJObject()}
    rooms[record.roomId]["sessions"][record.sessionId] =
      if record.sessionData.isNil: newJObject() else: record.sessionData.copy()
  %*{"rooms": rooms}

proc backupRoomSessionsPayload*(records: openArray[BackupSessionData]; roomId: string): JsonNode =
  var sorted: seq[BackupSessionData] = @[]
  for record in records:
    if record.roomId == roomId:
      sorted.add(record)
  sorted.sort(proc(a, b: BackupSessionData): int = cmp(a.sessionId, b.sessionId))
  var sessions = newJObject()
  for record in sorted:
    sessions[record.sessionId] = if record.sessionData.isNil: newJObject() else: record.sessionData.copy()
  %*{"sessions": sessions}

proc backupMutationPayload*(count: int; etag: string): JsonNode =
  %*{"count": count, "etag": etag}

proc backupVersionCreateResponse*(version: string): JsonNode =
  %*{"version": version}

proc backupMetadataPolicy*(body: JsonNode): BackupPolicyResult =
  if body.isNil or body.kind != JObject:
    return (false, "M_BAD_JSON", "Invalid backup metadata.")
  (true, "", "")

proc betterBackupSessionCandidate*(oldData, newData: JsonNode): tuple[ok: bool, replace: bool, message: string] =
  if newData.isNil or not newData.hasKey("is_verified"):
    return (false, false, "`is_verified` field should exist")
  if not newData.hasKey("first_message_index"):
    return (false, false, "`first_message_index` field should exist")
  if not newData.hasKey("forwarded_count"):
    return (false, false, "`forwarded_count` field should exist")

  let oldVerified = oldData{"is_verified"}.getBool(false)
  let newVerified = newData{"is_verified"}.getBool(false)
  if oldVerified != newVerified:
    return (true, newVerified, "")

  let oldFirst = oldData{"first_message_index"}.getInt(high(int))
  let newFirst = newData{"first_message_index"}.getInt(high(int))
  if oldFirst != newFirst:
    return (true, newFirst < oldFirst, "")

  let oldForwarded = oldData{"forwarded_count"}.getInt(high(int))
  let newForwarded = newData{"forwarded_count"}.getInt(high(int))
  (true, newForwarded < oldForwarded, "")

proc backupWriteResponse*(): JsonNode =
  newJObject()

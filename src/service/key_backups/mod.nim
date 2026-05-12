const
  RustPath* = "service/key_backups/mod.rs"
  RustCrate* = "service"

import std/[algorithm, json, strutils, tables]

type
  KeyBackupResult* = tuple[ok: bool, errcode: string, message: string]
  BackupVersionFetchResult* = tuple[ok: bool, version: string, metadata: JsonNode]
  BackupSessionFetchResult* = tuple[ok: bool, keyData: JsonNode]

  BackupVersionRecord* = object
    userId*: string
    version*: string
    algorithm*: string
    authData*: JsonNode
    metadata*: JsonNode
    etag*: string

  BackupSessionRecord* = object
    userId*: string
    version*: string
    roomId*: string
    sessionId*: string
    keyData*: JsonNode

  KeyBackupService* = object
    versions*: Table[string, BackupVersionRecord]
    sessions*: Table[string, BackupSessionRecord]
    nextCount*: uint64

proc initKeyBackupService*(): KeyBackupService =
  KeyBackupService(
    versions: initTable[string, BackupVersionRecord](),
    sessions: initTable[string, BackupSessionRecord](),
    nextCount: 0'u64,
  )

proc backupVersionKey*(userId, version: string): string =
  userId & "\0" & version

proc backupSessionKey*(userId, version, roomId, sessionId: string): string =
  userId & "\0" & version & "\0" & roomId & "\0" & sessionId

proc nextCount(service: var KeyBackupService): uint64 =
  inc service.nextCount
  service.nextCount

proc okResult(): KeyBackupResult =
  (true, "", "")

proc backupError(errcode, message: string): KeyBackupResult =
  (false, errcode, message)

proc metadataCopy(metadata: JsonNode): JsonNode =
  if metadata.isNil:
    %*{"algorithm": "m.megolm_backup.v1.curve25519-aes-sha2", "auth_data": {}}
  else:
    metadata.copy()

proc createBackup*(service: var KeyBackupService; userId: string; backupMetadata: JsonNode): string =
  let version = $service.nextCount()
  let etag = $service.nextCount()
  let metadata = metadataCopy(backupMetadata)
  service.versions[backupVersionKey(userId, version)] = BackupVersionRecord(
    userId: userId,
    version: version,
    algorithm: metadata{"algorithm"}.getStr("m.megolm_backup.v1.curve25519-aes-sha2"),
    authData: if metadata{"auth_data"}.isNil: newJObject() else: metadata["auth_data"].copy(),
    metadata: metadata,
    etag: etag,
  )
  version

proc backupVersionExists*(service: KeyBackupService; userId, version: string): bool =
  backupVersionKey(userId, version) in service.versions

proc deleteBackup*(service: var KeyBackupService; userId, version: string) =
  service.versions.del(backupVersionKey(userId, version))
  var deleteKeys: seq[string] = @[]
  for key, record in service.sessions:
    if record.userId == userId and record.version == version:
      deleteKeys.add(key)
  for key in deleteKeys:
    service.sessions.del(key)

proc updateBackup*(service: var KeyBackupService; userId, version: string; backupMetadata: JsonNode): KeyBackupResult =
  let key = backupVersionKey(userId, version)
  if key notin service.versions:
    return backupError("M_NOT_FOUND", "Tried to update nonexistent backup.")
  let metadata = metadataCopy(backupMetadata)
  var record = service.versions[key]
  record.algorithm = metadata{"algorithm"}.getStr(record.algorithm)
  record.authData = if metadata{"auth_data"}.isNil: newJObject() else: metadata["auth_data"].copy()
  record.metadata = metadata
  record.etag = $service.nextCount()
  service.versions[key] = record
  okResult()

proc getLatestBackupVersion*(service: KeyBackupService; userId: string): tuple[ok: bool, version: string] =
  var versions: seq[uint64] = @[]
  for record in service.versions.values:
    if record.userId == userId:
      try:
        versions.add(parseUInt(record.version))
      except ValueError:
        discard
  versions.sort(system.cmp[uint64])
  if versions.len == 0:
    return (false, "")
  (true, $versions[^1])

proc getLatestBackup*(service: KeyBackupService; userId: string): BackupVersionFetchResult =
  let latest = service.getLatestBackupVersion(userId)
  if not latest.ok:
    return (false, "", newJObject())
  let key = backupVersionKey(userId, latest.version)
  (true, latest.version, service.versions[key].metadata.copy())

proc getBackup*(service: KeyBackupService; userId, version: string): BackupVersionFetchResult =
  let key = backupVersionKey(userId, version)
  if key notin service.versions:
    return (false, "", newJObject())
  (true, version, service.versions[key].metadata.copy())

proc touchBackup(service: var KeyBackupService; userId, version: string) =
  let key = backupVersionKey(userId, version)
  if key in service.versions:
    var record = service.versions[key]
    record.etag = $service.nextCount()
    service.versions[key] = record

proc addKey*(
  service: var KeyBackupService;
  userId, version, roomId, sessionId: string;
  keyData: JsonNode;
): KeyBackupResult =
  if not service.backupVersionExists(userId, version):
    return backupError("M_NOT_FOUND", "Tried to update nonexistent backup.")
  service.touchBackup(userId, version)
  service.sessions[backupSessionKey(userId, version, roomId, sessionId)] = BackupSessionRecord(
    userId: userId,
    version: version,
    roomId: roomId,
    sessionId: sessionId,
    keyData: if keyData.isNil: newJObject() else: keyData.copy(),
  )
  okResult()

proc countKeys*(service: KeyBackupService; userId, version: string): int =
  result = 0
  for record in service.sessions.values:
    if record.userId == userId and record.version == version:
      inc result

proc getEtag*(service: KeyBackupService; userId, version: string): string =
  result = ""
  let key = backupVersionKey(userId, version)
  if key in service.versions:
    result = service.versions[key].etag

proc getAll*(service: KeyBackupService; userId, version: string): OrderedTable[string, OrderedTable[string, JsonNode]] =
  result = initOrderedTable[string, OrderedTable[string, JsonNode]]()
  var records: seq[BackupSessionRecord] = @[]
  for record in service.sessions.values:
    if record.userId == userId and record.version == version:
      records.add(record)
  records.sort(proc(a, b: BackupSessionRecord): int =
    result = cmp(a.roomId, b.roomId)
    if result == 0:
      result = cmp(a.sessionId, b.sessionId)
  )
  for record in records:
    if record.roomId notin result:
      result[record.roomId] = initOrderedTable[string, JsonNode]()
    result[record.roomId][record.sessionId] = record.keyData.copy()

proc getRoom*(service: KeyBackupService; userId, version, roomId: string): OrderedTable[string, JsonNode] =
  result = initOrderedTable[string, JsonNode]()
  var records: seq[BackupSessionRecord] = @[]
  for record in service.sessions.values:
    if record.userId == userId and record.version == version and record.roomId == roomId:
      records.add(record)
  records.sort(proc(a, b: BackupSessionRecord): int = cmp(a.sessionId, b.sessionId))
  for record in records:
    result[record.sessionId] = record.keyData.copy()

proc getSession*(service: KeyBackupService; userId, version, roomId, sessionId: string): BackupSessionFetchResult =
  let key = backupSessionKey(userId, version, roomId, sessionId)
  if key notin service.sessions:
    return (false, newJObject())
  (true, service.sessions[key].keyData.copy())

proc deleteAllKeys*(service: var KeyBackupService; userId, version: string) =
  var deleteKeys: seq[string] = @[]
  for key, record in service.sessions:
    if record.userId == userId and record.version == version:
      deleteKeys.add(key)
  for key in deleteKeys:
    service.sessions.del(key)
  service.touchBackup(userId, version)

proc deleteRoomKeys*(service: var KeyBackupService; userId, version, roomId: string) =
  var deleteKeys: seq[string] = @[]
  for key, record in service.sessions:
    if record.userId == userId and record.version == version and record.roomId == roomId:
      deleteKeys.add(key)
  for key in deleteKeys:
    service.sessions.del(key)
  service.touchBackup(userId, version)

proc deleteRoomKey*(service: var KeyBackupService; userId, version, roomId, sessionId: string) =
  service.sessions.del(backupSessionKey(userId, version, roomId, sessionId))
  service.touchBackup(userId, version)

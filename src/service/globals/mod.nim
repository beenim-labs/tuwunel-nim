const
  RustPath* = "service/globals/mod.rs"
  RustCrate* = "service"

import std/strutils

import service/globals/data

export data

type
  GlobalsService* = object
    db*: GlobalData
    serverName*: string
    serverUser*: string
    turnSecret*: string

proc initGlobalsService*(
  serverName: string;
  storedCount = 0'u64;
  databaseVersion = 0'u64;
  turnSecret = "";
): GlobalsService =
  GlobalsService(
    db: initGlobalData(storedCount, databaseVersion),
    serverName: serverName,
    serverUser: "@conduit:" & serverName,
    turnSecret: turnSecret,
  )

proc waitPending*(service: GlobalsService): uint64 =
  service.db.waitPending()

proc waitCount*(service: GlobalsService; count: uint64): tuple[ok: bool, retired: uint64] =
  service.db.waitCount(count)

proc nextCount*(service: var GlobalsService): CountPermit =
  service.db.nextCount()

proc currentCount*(service: GlobalsService): uint64 =
  service.db.currentCount()

proc pendingCount*(service: GlobalsService): CountRange =
  service.db.pendingCount()

proc serverNameValue*(service: GlobalsService): string =
  service.serverName

proc serverNameFromUserId(userId: string): string =
  let idx = userId.rfind(':')
  if idx < 0 or idx >= userId.high:
    return ""
  userId[idx + 1 .. ^1]

proc serverNameFromAlias(alias: string): string =
  serverNameFromUserId(alias)

proc serverIsOurs*(service: GlobalsService; serverName: string): bool =
  serverName == service.serverName

proc userIsLocal*(service: GlobalsService; userId: string): bool =
  service.serverIsOurs(serverNameFromUserId(userId))

proc aliasIsLocal*(service: GlobalsService; alias: string): bool =
  service.serverIsOurs(serverNameFromAlias(alias))

proc isReadOnly*(service: GlobalsService): bool =
  false

proc initRustlsProvider*(service: GlobalsService): bool =
  true

const
  RustPath* = "service/globals/data.rs"
  RustCrate* = "service"

type
  CountRange* = object
    start*: uint64
    stop*: uint64

  CountPermit* = object
    count*: uint64
    retired*: bool

  GlobalData* = object
    count*: uint64
    retired*: uint64
    dbVersion*: uint64

proc initGlobalData*(storedCount = 0'u64; databaseVersion = 0'u64): GlobalData =
  GlobalData(count: storedCount, retired: storedCount, dbVersion: databaseVersion)

proc waitPending*(data: GlobalData): uint64 =
  data.retired

proc waitCount*(data: GlobalData; count: uint64): tuple[ok: bool, retired: uint64] =
  (data.retired >= count, data.retired)

proc nextCount*(data: var GlobalData): CountPermit =
  inc data.count
  data.retired = data.count
  CountPermit(count: data.count, retired: true)

proc currentCount*(data: GlobalData): uint64 =
  data.count

proc pendingCount*(data: GlobalData): CountRange =
  CountRange(start: data.retired, stop: data.count)

proc bumpDatabaseVersion*(data: var GlobalData; newVersion: uint64) =
  data.dbVersion = newVersion

proc databaseVersion*(data: GlobalData): uint64 =
  data.dbVersion

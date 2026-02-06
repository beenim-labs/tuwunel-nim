import std/unittest

when defined(tuwunel_use_rocksdb):
  import std/[os, times, strformat, sets, options]
  import rocksdb
  import database/[db, serialization, generated_column_family_descriptors, types]

  var tempDbCounter = 0

  proc nextCounter(): int =
    inc tempDbCounter
    tempDbCounter

  proc tempDbPath(): string =
    let ts = now().toTime().toUnix()
    let n = nextCounter()
    result = getTempDir() / fmt"tuwunel_nim_rocksdb_{ts}_{getCurrentProcessId()}_{n}"

  suite "Database runtime (rocksdb backend)":
    test "open/list schema":
      let path = tempDbPath()
      if dirExists(path):
        removeDir(path)

      var d: DatabaseHandle
      try:
        d = db.openRocksDb(path)
        let got = d.listColumnFamilies().toHashSet()
        for cf in RequiredDatabaseColumnFamilies:
          check cf in got
      finally:
        if not d.isNil:
          d.close()
        if dirExists(path):
          removeDir(path)

    test "put/get/delete":
      let path = tempDbPath()
      if dirExists(path):
        removeDir(path)

      var d: DatabaseHandle
      try:
        d = db.openRocksDb(path)
        let cf = "global"
        let key = serializeStringAndU64("server_name", 42'u64)
        let val = toByteSeq("example.org")

        check not d.contains(cf, key)
        d.put(cf, key, val)
        check d.contains(cf, key)

        let got = d.get(cf, key)
        check got.isSome
        check fromByteSeq(got.get) == "example.org"

        check d.del(cf, key)
        check not d.contains(cf, key)
      finally:
        if not d.isNil:
          d.close()
        if dirExists(path):
          removeDir(path)

    test "existing schema missing required families is rejected":
      let path = tempDbPath()
      if dirExists(path):
        removeDir(path)

      var low: RocksDbReadWriteRef
      try:
        let cfs = @[initColFamilyDescriptor("global", defaultColFamilyOptions(autoClose = true))]
        low = openRocksDb(path, columnFamilies = cfs).value()
        low.close()

        expect DbError:
          discard db.openRocksDb(path)
      finally:
        if not low.isNil and not low.isClosed():
          low.close()

      if dirExists(path):
        removeDir(path)

else:
  suite "Database runtime (rocksdb backend)":
    test "disabled without compile flag":
      check true

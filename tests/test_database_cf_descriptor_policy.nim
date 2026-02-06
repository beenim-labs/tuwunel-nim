import std/[sequtils, unittest]
import database/generated_column_family_descriptors

suite "Database column-family descriptor policy":
  test "descriptor inventory contains required and dropped families":
    check DatabaseColumnFamilyDescriptors.len > 0
    check RequiredDatabaseColumnFamilies.len > 0
    check DatabaseColumnFamilyDescriptors.anyIt(it.dropped)

    for name in RequiredDatabaseColumnFamilies:
      let matches = DatabaseColumnFamilyDescriptors.filterIt(it.name == name)
      check matches.len == 1
      check not matches[0].dropped

when defined(tuwunel_use_rocksdb):
  import std/[os, strformat, times]
  import rocksdb
  import database/[backend_rocksdb, types]

  proc tempDbPath(tag: string): string =
    let ts = now().toTime().toUnix()
    getTempDir() / fmt"tuwunel_nim_cf_policy_{tag}_{getCurrentProcessId()}_{ts}"

  proc descriptorsFor(names: openArray[string]): seq[ColFamilyDescriptor] =
    result = @[]
    for name in names:
      result.add(initColFamilyDescriptor(name, defaultColFamilyOptions(autoClose = true)))

  suite "Database column-family descriptor policy (rocksdb)":
    test "unknown on-disk families are tolerated":
      let path = tempDbPath("unknown")
      if dirExists(path):
        removeDir(path)

      var db: RocksDbReadWriteRef
      var backend: RocksDbBackend
      try:
        var names = @RequiredDatabaseColumnFamilies
        names.add("legacy_unknown_cf")
        db = openRocksDb(path, columnFamilies = descriptorsFor(names)).value()
        db.close()

        backend = openRocksDbBackend(path, DatabaseColumnFamilyDescriptors)
        let listed = backend.listColumnFamilies()
        check "legacy_unknown_cf" in listed
      finally:
        if not backend.isNil:
          backend.close()
        if not db.isNil and not db.isClosed():
          db.close()
        if dirExists(path):
          removeDir(path)

    test "missing required families are rejected on existing db":
      let path = tempDbPath("missing")
      if dirExists(path):
        removeDir(path)

      var db: RocksDbReadWriteRef
      try:
        let names = @[RequiredDatabaseColumnFamilies[0]]
        db = openRocksDb(path, columnFamilies = descriptorsFor(names)).value()
        db.close()

        expect DbError:
          discard openRocksDbBackend(path, DatabaseColumnFamilyDescriptors)
      finally:
        if not db.isNil and not db.isClosed():
          db.close()
        if dirExists(path):
          removeDir(path)

## Database handle for tuwunel-nim M3 foundation.

import std/[options]
import generated_column_families
import schema
import backend_memory
import backend_rocksdb

type
  DbMode* = enum
    dmInMemory
    dmRocksDb

  DatabaseHandle* = ref object
    mode*: DbMode
    path*: string
    memory*: InMemoryBackend
    rocks*: RocksDbBackend

proc openInMemory*(path = ":memory:"; columnFamilies = DatabaseColumnFamilies): DatabaseHandle =
  new(result)
  result.mode = dmInMemory
  result.path = path
  result.memory = newInMemoryBackend(columnFamilies)

proc openRocksDb*(path: string; columnFamilies = DatabaseColumnFamilies): DatabaseHandle =
  new(result)
  result.mode = dmRocksDb
  result.path = path
  result.rocks = openRocksDbBackend(path, columnFamilies)

proc close*(db: DatabaseHandle) =
  if db.isNil:
    return

  case db.mode
  of dmInMemory:
    discard
  of dmRocksDb:
    if not db.rocks.isNil:
      db.rocks.close()

proc put*(db: DatabaseHandle; cf: string; key, val: openArray[byte]) =
  case db.mode
  of dmInMemory:
    db.memory.put(cf, key, val)
  of dmRocksDb:
    db.rocks.put(cf, key, val)

proc get*(db: DatabaseHandle; cf: string; key: openArray[byte]): Option[seq[byte]] =
  case db.mode
  of dmInMemory:
    db.memory.get(cf, key)
  of dmRocksDb:
    db.rocks.get(cf, key)

proc contains*(db: DatabaseHandle; cf: string; key: openArray[byte]): bool =
  case db.mode
  of dmInMemory:
    db.memory.contains(cf, key)
  of dmRocksDb:
    db.rocks.contains(cf, key)

proc del*(db: DatabaseHandle; cf: string; key: openArray[byte]): bool =
  case db.mode
  of dmInMemory:
    db.memory.del(cf, key)
  of dmRocksDb:
    db.rocks.del(cf, key)

proc count*(db: DatabaseHandle; cf: string): int =
  case db.mode
  of dmInMemory:
    db.memory.count(cf)
  of dmRocksDb:
    db.rocks.count(cf)

proc listColumnFamilies*(db: DatabaseHandle): seq[string] =
  case db.mode
  of dmInMemory:
    db.memory.listColumnFamilies()
  of dmRocksDb:
    db.rocks.listColumnFamilies()

proc assertSchemaCompatible*(actual: openArray[string]) =
  ensureSchemaCompatible(actual)

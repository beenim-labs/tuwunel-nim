## Database handle and helper APIs for tuwunel-nim M3 parity baseline.

import std/options
import backend_memory
import backend_rocksdb
import de
import generated_column_families
import generated_column_family_descriptors
import keyval
import schema
import serialization

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

proc openRocksDb*(
    path: string;
    options = defaultRocksDbOpenOptions();
    descriptors = DatabaseColumnFamilyDescriptors): DatabaseHandle =
  new(result)
  result.mode = dmRocksDb
  result.path = path
  result.rocks = openRocksDbBackend(path, descriptors, options)

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

proc putString*(db: DatabaseHandle; cf, key, value: string) =
  db.put(cf, toByteSeq(key), serializeStringValue(value))

proc getString*(db: DatabaseHandle; cf, key: string): Option[string] =
  let raw = db.get(cf, toByteSeq(key))
  if raw.isNone:
    return none(string)
  some(deserializeStringValue(raw.get))

proc putU64*(db: DatabaseHandle; cf, key: string; value: uint64) =
  db.put(cf, toByteSeq(key), serializeU64Value(value))

proc getU64*(db: DatabaseHandle; cf, key: string): Option[uint64] =
  let raw = db.get(cf, toByteSeq(key))
  if raw.isNone:
    return none(uint64)
  some(deserializeU64Value(raw.get))

proc putTupleKeyVal*(db: DatabaseHandle; cf: string; keyParts, valParts: openArray[seq[byte]]) =
  let key = serializeKey(keyParts)
  let value = serializeKey(valParts)
  db.put(cf, key, value)

proc getTuple2Value*(
    db: DatabaseHandle; cf: string; key: openArray[byte]): Option[tuple[a: seq[byte], b: seq[
    byte]]] =
  let raw = db.get(cf, key)
  if raw.isNone:
    return none((tuple[a: seq[byte], b: seq[byte]]))
  some(deserializeTuple2Bytes(raw.get))

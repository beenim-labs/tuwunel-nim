## RocksDB backend implementation.

import std/options
import types

when defined(tuwunel_use_rocksdb):
  when defined(macosx):
    {.passL: "-lc++".}
  else:
    {.passL: "-lstdc++".}

  import std/[os, tables]
  import schema
  import rocksdb

  type
    RocksDbBackend* = ref object
      path*: string
      db*: RocksDbReadWriteRef
      cfHandles*: Table[string, ColFamilyHandleRef]

  proc fail(msg: string): ref DbError {.inline.} =
    newDbError(msg)

  proc expectOk(res: RocksDBResult[void]; ctx: string) =
    if res.isErr:
      raise fail(ctx & ": " & res.error())

  proc expectVal[T](res: RocksDBResult[T]; ctx: string): T =
    if res.isErr:
      raise fail(ctx & ": " & res.error())
    res.value()

  proc normalizeOnDisk(onDisk: openArray[string]): seq[string] =
    result = @[]
    for cf in onDisk:
      if cf != DEFAULT_COLUMN_FAMILY_NAME:
        result.add(cf)

  proc hasEntries(path: string): bool =
    if not dirExists(path):
      return false
    for _ in walkDir(path):
      return true
    false

  proc toDescriptors(columnFamilies: openArray[string]): seq[ColFamilyDescriptor] =
    result = @[]
    for cf in columnFamilies:
      result.add(initColFamilyDescriptor(cf, defaultColFamilyOptions(autoClose = true)))

  proc openRocksDbBackend*(path: string; columnFamilies: openArray[string]): RocksDbBackend =
    if path.len == 0:
      raise fail("RocksDB path cannot be empty")

    if dirExists(path):
      let listRes = listColumnFamilies(path)
      if listRes.isOk:
        let onDisk = normalizeOnDisk(listRes.value())
        ensureSchemaCompatible(onDisk, @columnFamilies)
      elif hasEntries(path):
        raise fail("Unable to list on-disk column families: " & listRes.error())

    let dbRes = openRocksDb(path, columnFamilies = toDescriptors(columnFamilies))
    let rocks = expectVal(dbRes, "openRocksDb")

    var handles = initTable[string, ColFamilyHandleRef]()
    for cf in columnFamilies:
      let handleRes = rocks.getColFamilyHandle(cf)
      handles[cf] = expectVal(handleRes, "getColFamilyHandle(" & cf & ")")

    new(result)
    result.path = path
    result.db = rocks
    result.cfHandles = handles

  proc close*(backend: RocksDbBackend) =
    if backend.isNil:
      return
    if not backend.db.isNil and not backend.db.isClosed():
      backend.db.close()

  proc requireCf(backend: RocksDbBackend; cf: string): ColFamilyHandleRef =
    if cf notin backend.cfHandles:
      raise fail("Unknown column family: " & cf)
    backend.cfHandles[cf]

  proc put*(backend: RocksDbBackend; cf: string; key, val: openArray[byte]) =
    let handle = requireCf(backend, cf)
    expectOk(backend.db.put(key, val, handle), "rocksdb put(" & cf & ")")

  proc get*(backend: RocksDbBackend; cf: string; key: openArray[byte]): Option[seq[byte]] =
    let handle = requireCf(backend, cf)
    var valueBuf: seq[byte] = @[]

    let res = backend.db.get(
      key,
      proc(data: openArray[byte]) =
        valueBuf = @data,
      handle,
    )

    if res.isErr:
      raise fail("rocksdb get(" & cf & "): " & res.error())

    if res.value():
      return some(valueBuf)

    none(seq[byte])

  proc contains*(backend: RocksDbBackend; cf: string; key: openArray[byte]): bool =
    let handle = requireCf(backend, cf)
    let res = backend.db.keyExists(key, handle)
    if res.isErr:
      raise fail("rocksdb keyExists(" & cf & "): " & res.error())
    res.value()

  proc del*(backend: RocksDbBackend; cf: string; key: openArray[byte]): bool =
    let handle = requireCf(backend, cf)
    let existed = backend.contains(cf, key)
    expectOk(backend.db.delete(key, handle), "rocksdb delete(" & cf & ")")
    existed

  proc count*(backend: RocksDbBackend; cf: string): int =
    result = 0
    let handle = requireCf(backend, cf)
    let iterRes = backend.db.openIterator(cfHandle = handle)
    let iter = expectVal(iterRes, "rocksdb openIterator(" & cf & ")")
    for _ in iter.pairs:
      inc result

  proc listColumnFamilies*(backend: RocksDbBackend): seq[string] =
    result = @[]
    for name in backend.cfHandles.keys:
      result.add(name)

else:
  type
    RocksDbBackend* = ref object

  proc openRocksDbBackend*(path: string; columnFamilies: openArray[string]): RocksDbBackend =
    discard path
    discard columnFamilies
    raise newDbError("Compile with -d:tuwunel_use_rocksdb and a RocksDB Nim dependency path")

  proc close*(backend: RocksDbBackend) =
    discard backend

  proc put*(backend: RocksDbBackend; cf: string; key, val: openArray[byte]) =
    discard backend
    discard cf
    discard key
    discard val
    raise newDbError("RocksDB backend not enabled")

  proc get*(backend: RocksDbBackend; cf: string; key: openArray[byte]): Option[seq[byte]] =
    discard backend
    discard cf
    discard key
    raise newDbError("RocksDB backend not enabled")

  proc contains*(backend: RocksDbBackend; cf: string; key: openArray[byte]): bool =
    discard backend
    discard cf
    discard key
    raise newDbError("RocksDB backend not enabled")

  proc del*(backend: RocksDbBackend; cf: string; key: openArray[byte]): bool =
    discard backend
    discard cf
    discard key
    raise newDbError("RocksDB backend not enabled")

  proc count*(backend: RocksDbBackend; cf: string): int =
    discard backend
    discard cf
    raise newDbError("RocksDB backend not enabled")

  proc listColumnFamilies*(backend: RocksDbBackend): seq[string] =
    discard backend
    raise newDbError("RocksDB backend not enabled")

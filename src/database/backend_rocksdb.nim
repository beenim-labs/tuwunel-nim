## RocksDB backend implementation.

import std/options
import generated_column_family_descriptors
import types

type
  RocksDbOpenOptions* = object
    readOnly*: bool
    secondary*: bool
    repair*: bool
    neverDropColumns*: bool
    secondaryPath*: string

proc defaultRocksDbOpenOptions*(): RocksDbOpenOptions =
  RocksDbOpenOptions(
    readOnly: false,
    secondary: false,
    repair: false,
    neverDropColumns: false,
    secondaryPath: "",
  )

when defined(tuwunel_use_rocksdb):
  when defined(macosx):
    {.passL: "-lc++".}
  else:
    {.passL: "-lstdc++".}

  import std/[algorithm, os, sets, tables]
  import rocksdb
  import rocksdb/lib/librocksdb
  import rocksdb/options/dbopts

  type
    RocksDbBackend* = ref object
      path*: string
      readOnly*: bool
      readOnlyDb*: RocksDbReadOnlyRef
      readWriteDb*: RocksDbReadWriteRef
      cfHandles*: Table[string, ColFamilyHandleRef]
      unknownOnDisk*: seq[string]
      openOptions*: RocksDbOpenOptions

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

  proc descriptorNames(descriptors: openArray[DatabaseColumnFamilyDescriptor]): seq[string] =
    result = @[]
    for d in descriptors:
      result.add(d.name)

  proc requiredNames(descriptors: openArray[DatabaseColumnFamilyDescriptor]): seq[string] =
    result = @[]
    for d in descriptors:
      if not d.dropped and not d.ignored:
        result.add(d.name)

  proc uniqueAppend(dst: var seq[string]; src: openArray[string]) =
    var seen = dst.toHashSet()
    for value in src:
      if value in seen:
        continue
      seen.incl(value)
      dst.add(value)

  proc compareBytes(a, b: openArray[byte]): int =
    let m = min(a.len, b.len)
    var i = 0
    while i < m:
      if a[i] < b[i]:
        return -1
      if a[i] > b[i]:
        return 1
      inc i

    if a.len < b.len:
      return -1
    if a.len > b.len:
      return 1
    0

  proc ensureRequiredOnDisk(onDisk, required: openArray[string]) =
    let onDiskSet = onDisk.toHashSet()
    var missing: seq[string] = @[]
    for cf in required:
      if cf notin onDiskSet:
        missing.add(cf)

    if missing.len > 0:
      missing.sort(system.cmp[string])
      raise fail("Column-family schema mismatch missing=" & $missing)

  proc maybeRepair(path: string; options: RocksDbOpenOptions) =
    if not options.repair:
      return

    let dbOpts = defaultDbOptions(autoClose = true)
    var errors: cstring = nil
    rocksdb_repair_db(dbOpts.cPtr, path.cstring, cast[cstringArray](errors.addr))
    if not errors.isNil:
      let msg = $errors
      rocksdb_free(errors)
      raise fail("rocksdb repair: " & msg)

  proc dbRef(backend: RocksDbBackend): RocksDbRef =
    if backend.readOnly:
      return RocksDbRef(backend.readOnlyDb)
    RocksDbRef(backend.readWriteDb)

  proc openRocksDbBackend*(
      path: string;
      descriptors: openArray[DatabaseColumnFamilyDescriptor];
      options = defaultRocksDbOpenOptions()): RocksDbBackend =
    if path.len == 0:
      raise fail("RocksDB path cannot be empty")

    if options.secondary:
      raise fail("rocksdb secondary mode is not supported by current Nim binding")

    maybeRepair(path, options)

    let known = descriptorNames(descriptors)
    let required = requiredNames(descriptors)

    var onDisk: seq[string] = @[]
    var unknownOnDisk: seq[string] = @[]
    if dirExists(path):
      let listRes = listColumnFamilies(path)
      if listRes.isOk:
        onDisk = normalizeOnDisk(listRes.value())
        if onDisk.len > 0:
          ensureRequiredOnDisk(onDisk, required)

        let knownSet = known.toHashSet()
        for cf in onDisk:
          if cf notin knownSet:
            unknownOnDisk.add(cf)
      elif hasEntries(path):
        raise fail("Unable to list on-disk column families: " & listRes.error())

    var openFamilies = @required
    # Any pre-existing unknown column families must be included to avoid failing
    # database open on compatible downgrades or mixed histories.
    uniqueAppend(openFamilies, onDisk)

    let cfs = toDescriptors(openFamilies)

    let unknownSet = unknownOnDisk.toHashSet()
    var handles = initTable[string, ColFamilyHandleRef]()
    var ro: RocksDbReadOnlyRef = nil
    var rw: RocksDbReadWriteRef = nil

    if options.readOnly:
      ro = expectVal(openRocksDbReadOnly(path, columnFamilies = cfs), "openRocksDbReadOnly")
      for cf in openFamilies:
        let handleRes = ro.getColFamilyHandle(cf)
        if handleRes.isErr:
          if cf in unknownSet:
            continue
          raise fail("getColFamilyHandle(" & cf & "): " & handleRes.error())
        handles[cf] = handleRes.value()
    else:
      rw = expectVal(openRocksDb(path, columnFamilies = cfs), "openRocksDb")
      for cf in openFamilies:
        let handleRes = rw.getColFamilyHandle(cf)
        if handleRes.isErr:
          if cf in unknownSet:
            continue
          raise fail("getColFamilyHandle(" & cf & "): " & handleRes.error())
        handles[cf] = handleRes.value()

    new(result)
    result.path = path
    result.readOnly = options.readOnly
    result.readOnlyDb = ro
    result.readWriteDb = rw
    result.cfHandles = handles
    result.unknownOnDisk = unknownOnDisk
    result.openOptions = options

  proc close*(backend: RocksDbBackend) =
    if backend.isNil:
      return
    if not backend.readWriteDb.isNil and not backend.readWriteDb.isClosed():
      backend.readWriteDb.close()
    if not backend.readOnlyDb.isNil and not backend.readOnlyDb.isClosed():
      backend.readOnlyDb.close()

  proc requireCf(backend: RocksDbBackend; cf: string): ColFamilyHandleRef =
    if cf notin backend.cfHandles:
      raise fail("Unknown column family: " & cf)
    backend.cfHandles[cf]

  proc put*(backend: RocksDbBackend; cf: string; key, val: openArray[byte]) =
    if backend.readOnly:
      raise fail("rocksdb put disallowed in read-only mode")
    let handle = requireCf(backend, cf)
    expectOk(backend.readWriteDb.put(key, val, handle), "rocksdb put(" & cf & ")")

  proc get*(backend: RocksDbBackend; cf: string; key: openArray[byte]): Option[seq[byte]] =
    let handle = requireCf(backend, cf)
    var valueBuf: seq[byte] = @[]

    let res = backend.dbRef().get(
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
    let res = backend.dbRef().keyExists(key, handle)
    if res.isErr:
      raise fail("rocksdb keyExists(" & cf & "): " & res.error())
    res.value()

  proc del*(backend: RocksDbBackend; cf: string; key: openArray[byte]): bool =
    if backend.readOnly:
      raise fail("rocksdb delete disallowed in read-only mode")
    let handle = requireCf(backend, cf)
    let existed = backend.contains(cf, key)
    expectOk(backend.readWriteDb.delete(key, handle), "rocksdb delete(" & cf & ")")
    existed

  proc count*(backend: RocksDbBackend; cf: string): int =
    result = 0
    let handle = requireCf(backend, cf)
    let iterRes = backend.dbRef().openIterator(cfHandle = handle)
    let iter = expectVal(iterRes, "rocksdb openIterator(" & cf & ")")
    for _ in iter.pairs:
      inc result

  proc entries*(backend: RocksDbBackend; cf: string): seq[DbEntry] =
    result = @[]
    let handle = requireCf(backend, cf)
    let iterRes = backend.dbRef().openIterator(cfHandle = handle)
    let iter = expectVal(iterRes, "rocksdb openIterator(" & cf & ")")

    for key, value in iter.pairs:
      result.add((key: key, value: value))

    result.sort(
      proc(a, b: DbEntry): int =
        compareBytes(a.key, b.key)
    )

  proc listColumnFamilies*(backend: RocksDbBackend): seq[string] =
    result = @[]
    for name in backend.cfHandles.keys:
      result.add(name)
    for name in backend.unknownOnDisk:
      if name notin result:
        result.add(name)

  proc clearColumnFamily*(backend: RocksDbBackend; cf: string): int =
    if backend.readOnly:
      raise fail("rocksdb clear disallowed in read-only mode")

    let handle = requireCf(backend, cf)
    let iterRes = backend.dbRef().openIterator(cfHandle = handle)
    let iter = expectVal(iterRes, "rocksdb openIterator(" & cf & ")")

    var removed = 0
    for key, _ in iter.pairs:
      expectOk(backend.readWriteDb.delete(key, handle), "rocksdb clear(" & cf & ")")
      inc removed
    removed

else:
  type
    RocksDbBackend* = ref object

  proc openRocksDbBackend*(
      path: string;
      descriptors: openArray[DatabaseColumnFamilyDescriptor];
      options = defaultRocksDbOpenOptions()): RocksDbBackend =
    discard path
    discard descriptors
    discard options
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

  proc entries*(backend: RocksDbBackend; cf: string): seq[DbEntry] =
    discard backend
    discard cf
    raise newDbError("RocksDB backend not enabled")

  proc listColumnFamilies*(backend: RocksDbBackend): seq[string] =
    discard backend
    raise newDbError("RocksDB backend not enabled")

  proc clearColumnFamily*(backend: RocksDbBackend; cf: string): int =
    discard backend
    discard cf
    raise newDbError("RocksDB backend not enabled")

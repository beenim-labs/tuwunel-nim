## In-memory backend used as development fallback while RocksDB backend
## integration is being completed.

import std/[algorithm, tables, options, base64]
import schema
import types

type
  CfTable = Table[string, seq[byte]]

  InMemoryBackend* = ref object
    families*: Table[string, CfTable]

proc bytesToString(data: openArray[byte]): string =
  result = newString(data.len)
  for i, b in data:
    result[i] = char(b)

proc stringToBytes(data: string): seq[byte] =
  result = newSeq[byte](data.len)
  for i, ch in data:
    result[i] = byte(ord(ch))

proc bytesToKey(data: openArray[byte]): string =
  encode(bytesToString(data), safe = false)

proc keyToBytes(encoded: string): seq[byte] =
  try:
    let decoded = decode(encoded)
    stringToBytes(decoded)
  except CatchableError:
    @[]

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

proc newInMemoryBackend*(columnFamilies: openArray[string]): InMemoryBackend =
  ensureSchemaCompatible(columnFamilies)
  new(result)
  result.families = initTable[string, CfTable]()
  for cf in columnFamilies:
    result.families[cf] = initTable[string, seq[byte]]()

proc requireCf(db: InMemoryBackend; cf: string) =
  if cf notin db.families:
    raise newDbError("Unknown column family: " & cf)

proc put*(db: InMemoryBackend; cf: string; key, val: openArray[byte]) =
  requireCf(db, cf)
  var table = db.families[cf]
  table[bytesToKey(key)] = @val
  db.families[cf] = table

proc get*(db: InMemoryBackend; cf: string; key: openArray[byte]): Option[seq[byte]] =
  requireCf(db, cf)
  let table = db.families[cf]
  let k = bytesToKey(key)
  if k in table:
    return some(table[k])
  none(seq[byte])

proc contains*(db: InMemoryBackend; cf: string; key: openArray[byte]): bool =
  requireCf(db, cf)
  let table = db.families[cf]
  bytesToKey(key) in table

proc del*(db: InMemoryBackend; cf: string; key: openArray[byte]): bool =
  requireCf(db, cf)
  var table = db.families[cf]
  let k = bytesToKey(key)
  if k in table:
    table.del(k)
    db.families[cf] = table
    return true
  false

proc count*(db: InMemoryBackend; cf: string): int =
  requireCf(db, cf)
  let table = db.families[cf]
  table.len

proc entries*(db: InMemoryBackend; cf: string): seq[DbEntry] =
  requireCf(db, cf)
  result = @[]

  let table = db.families[cf]
  for encodedKey, value in table.pairs:
    result.add((key: keyToBytes(encodedKey), value: value))

  result.sort(
    proc(a, b: DbEntry): int =
      compareBytes(a.key, b.key)
  )

proc listColumnFamilies*(db: InMemoryBackend): seq[string] =
  result = @[]
  for k in db.families.keys:
    result.add(k)

proc clearColumnFamily*(db: InMemoryBackend; cf: string): int =
  requireCf(db, cf)
  let removed = db.families[cf].len
  db.families[cf] = initTable[string, seq[byte]]()
  removed

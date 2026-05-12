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

proc bytesToKey(data: openArray[byte]): string =
  encode(bytesToString(data), safe = false)

proc stringToBytes(data: string): seq[byte] =
  result = newSeq[byte](data.len)
  for i, c in data:
    result[i] = byte(ord(c))

proc keyToBytes(encoded: string): seq[byte] =
  stringToBytes(decode(encoded))

proc compareBytes(a, b: openArray[byte]): int =
  let common = min(a.len, b.len)
  for i in 0 ..< common:
    if a[i] < b[i]:
      return -1
    if a[i] > b[i]:
      return 1
  cmp(a.len, b.len)

proc startsWithBytes(value, prefix: openArray[byte]): bool =
  if prefix.len > value.len:
    return false
  for i in 0 ..< prefix.len:
    if value[i] != prefix[i]:
      return false
  true

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

proc clear*(db: InMemoryBackend; cf: string) =
  requireCf(db, cf)
  db.families[cf] = initTable[string, seq[byte]]()

proc scan*(
    db: InMemoryBackend;
    cf: string;
    fromKey: seq[byte] = @[];
    hasFrom = false;
    prefix: seq[byte] = @[];
    hasPrefix = false;
    reverse = false): seq[DbKeyValue] =
  requireCf(db, cf)
  let table = db.families[cf]
  result = @[]

  for encoded, value in table.pairs:
    let key = keyToBytes(encoded)
    if hasFrom:
      let relation = compareBytes(key, fromKey)
      if reverse:
        if relation > 0:
          continue
      elif relation < 0:
        continue
    if hasPrefix and not startsWithBytes(key, prefix):
      continue
    result.add((key: key, value: @value))

  result.sort(proc(a, b: DbKeyValue): int = compareBytes(a.key, b.key))
  if reverse:
    result.reverse()

proc count*(db: InMemoryBackend; cf: string): int =
  requireCf(db, cf)
  let table = db.families[cf]
  table.len

proc listColumnFamilies*(db: InMemoryBackend): seq[string] =
  result = @[]
  for k in db.families.keys:
    result.add(k)

## In-memory backend used as development fallback while RocksDB backend
## integration is being completed.

import std/[tables, options, base64]
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

proc listColumnFamilies*(db: InMemoryBackend): seq[string] =
  result = @[]
  for k in db.families.keys:
    result.add(k)

## Column-family schema compatibility helpers.

import std/[algorithm, sets]
import generated_column_families
import types

type
  SchemaDiff* = object
    missing*: seq[string]
    extra*: seq[string]

proc expectedColumnFamilies*(): seq[string] =
  DatabaseColumnFamilies

proc normalize(names: openArray[string]): seq[string] =
  result = @[]
  for name in names:
    if name.len > 0:
      result.add(name)
  result.sort(system.cmp[string])

proc computeSchemaDiff*(actual: openArray[string]; expected = DatabaseColumnFamilies): SchemaDiff =
  result = SchemaDiff(missing: @[], extra: @[])
  let actualSet = actual.toHashSet()
  let expectedSet = expected.toHashSet()

  for cf in expected:
    if cf notin actualSet:
      result.missing.add(cf)

  for cf in actual:
    if cf notin expectedSet:
      result.extra.add(cf)

  result.missing = normalize(result.missing)
  result.extra = normalize(result.extra)

proc isCompatible*(diff: SchemaDiff): bool =
  diff.missing.len == 0 and diff.extra.len == 0

proc ensureSchemaCompatible*(actual: openArray[string]; expected = DatabaseColumnFamilies) =
  let diff = computeSchemaDiff(actual, expected)
  if not isCompatible(diff):
    var msg = "Column-family schema mismatch"
    if diff.missing.len > 0:
      msg.add(" missing=" & $diff.missing)
    if diff.extra.len > 0:
      msg.add(" extra=" & $diff.extra)
    raise newDbError(msg)

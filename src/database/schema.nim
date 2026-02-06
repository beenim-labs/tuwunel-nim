## Column-family schema compatibility helpers.

import std/[algorithm, sets]
import generated_column_families
import generated_column_family_descriptors
import types

type
  SchemaDiff* = object
    missing*: seq[string]
    extra*: seq[string]

proc expectedColumnFamilies*(): seq[string] =
  DatabaseColumnFamilies

proc expectedRequiredColumnFamilies*(): seq[string] =
  RequiredDatabaseColumnFamilies

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

proc computeRequiredSchemaDiff*(
    actual: openArray[string]; required = RequiredDatabaseColumnFamilies): SchemaDiff =
  result = SchemaDiff(missing: @[], extra: @[])
  let actualSet = actual.toHashSet()
  let requiredSet = required.toHashSet()

  for cf in required:
    if cf notin actualSet:
      result.missing.add(cf)

  for cf in actual:
    if cf notin requiredSet:
      result.extra.add(cf)

  result.missing = normalize(result.missing)
  result.extra = normalize(result.extra)

proc ensureRequiredSchemaCompatible*(
    actual: openArray[string]; required = RequiredDatabaseColumnFamilies) =
  let diff = computeRequiredSchemaDiff(actual, required)
  if diff.missing.len > 0:
    raise newDbError("Column-family schema mismatch missing=" & $diff.missing)

import std/unittest
import database/[schema, generated_column_families]

suite "Database schema compatibility":
  test "generated families match expected count":
    check DatabaseColumnFamilies.len == 103
    check expectedColumnFamilies().len == 103

  test "exact match is compatible":
    let diff = computeSchemaDiff(DatabaseColumnFamilies)
    check isCompatible(diff)
    check diff.missing.len == 0
    check diff.extra.len == 0

  test "missing and extra are detected":
    var actual = DatabaseColumnFamilies
    actual.delete(0)
    actual.add("extra_cf")

    let diff = computeSchemaDiff(actual)
    check not isCompatible(diff)
    check "alias_roomid" in diff.missing
    check "extra_cf" in diff.extra

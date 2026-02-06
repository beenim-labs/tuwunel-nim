## Runtime self-check helpers for database module behavior.

import db
import serialization

proc runInMemorySelfCheck*(): bool =
  let database = openInMemory()
  defer:
    database.close()

  let cf = "global"
  let key = serializeStringAndU64("selfcheck", 1'u64)
  let value = toByteSeq("ok")

  if database.contains(cf, key):
    return false

  database.put(cf, key, value)
  if not database.contains(cf, key):
    return false

  let loaded = database.get(cf, key)
  if loaded.isNone:
    return false
  if loaded.get != value:
    return false

  if not database.del(cf, key):
    return false

  not database.contains(cf, key)

proc runSchemaCheck*(): bool =
  let database = openInMemory()
  let families = database.listColumnFamilies()
  families.len > 0

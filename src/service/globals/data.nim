import std/tables

const
  RustPath* = "service/globals/data.rs"
  RustCrate* = "service"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  GlobalDataStore* = ref object
    values*: Table[string, string]
    counters*: Table[string, int64]

proc newGlobalDataStore*(): GlobalDataStore =
  new(result)
  result.values = initTable[string, string]()
  result.counters = initTable[string, int64]()

proc setValue*(store: GlobalDataStore; key, value: string) =
  store.values[key] = value

proc getValue*(store: GlobalDataStore; key: string): string =
  store.values.getOrDefault(key, "")

proc hasValue*(store: GlobalDataStore; key: string): bool =
  key in store.values

proc addCounter*(store: GlobalDataStore; key: string; by: int64 = 1'i64): int64 =
  let current = store.counters.getOrDefault(key, 0'i64)
  let updated = current + by
  store.counters[key] = updated
  updated

proc counter*(store: GlobalDataStore; key: string): int64 =
  store.counters.getOrDefault(key, 0'i64)

proc valueCount*(store: GlobalDataStore): int =
  store.values.len

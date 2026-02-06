## Engine database option mapping.

import ../backend_rocksdb

type
  EngineDbOptions* = object
    readOnly*: bool
    secondary*: bool
    repair*: bool
    neverDropColumns*: bool
    secondaryPath*: string

proc defaultEngineDbOptions*(): EngineDbOptions =
  EngineDbOptions(
    readOnly: false,
    secondary: false,
    repair: false,
    neverDropColumns: false,
    secondaryPath: "",
  )

proc toRocksDbOpenOptions*(options: EngineDbOptions): RocksDbOpenOptions =
  RocksDbOpenOptions(
    readOnly: options.readOnly,
    secondary: options.secondary,
    repair: options.repair,
    neverDropColumns: options.neverDropColumns,
    secondaryPath: options.secondaryPath,
  )

proc withReadOnly*(options: EngineDbOptions; value = true): EngineDbOptions =
  result = options
  result.readOnly = value

proc withSecondary*(options: EngineDbOptions; value = true; path = ""): EngineDbOptions =
  result = options
  result.secondary = value
  result.secondaryPath = path

proc withRepair*(options: EngineDbOptions; value = true): EngineDbOptions =
  result = options
  result.repair = value

proc withNeverDropColumns*(options: EngineDbOptions; value = true): EngineDbOptions =
  result = options
  result.neverDropColumns = value

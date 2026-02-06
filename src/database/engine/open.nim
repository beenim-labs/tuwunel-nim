## Engine open helpers.

import ../db
import ../generated_column_families
import ../generated_column_family_descriptors
import context
import db_opts

type
  EngineOpenResult* = object
    database*: DatabaseHandle
    selectedDescriptorCount*: int

proc openEngine*(context: EngineContext): EngineOpenResult =
  let descriptors = context.selectedDescriptors()
  let options = context.dbOptions.toRocksDbOpenOptions()
  let database = openRocksDb(context.path, options, descriptors)
  EngineOpenResult(database: database, selectedDescriptorCount: descriptors.len)

proc openEngineDefault*(path: string): EngineOpenResult =
  let context = initEngineContext(path)
  openEngine(context)

proc openEngineReadOnly*(path: string): EngineOpenResult =
  let opts = defaultEngineDbOptions().withReadOnly(true)
  let context = initEngineContext(path, dbOptions = opts)
  openEngine(context)

proc openEngineRepair*(path: string): EngineOpenResult =
  let opts = defaultEngineDbOptions().withRepair(true)
  let context = initEngineContext(path, dbOptions = opts)
  openEngine(context)

proc openEngineInMemory*(columnFamilies = DatabaseColumnFamilies): DatabaseHandle =
  openInMemory(columnFamilies = columnFamilies)

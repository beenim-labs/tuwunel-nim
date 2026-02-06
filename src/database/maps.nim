## Registry helpers for opening all database maps.

import std/tables
import db
import map/open

type
  DatabaseMapRegistry* = object
    maps*: Table[string, MapHandle]

proc openMapRegistry*(database: DatabaseHandle): DatabaseMapRegistry =
  if database.isNil:
    raise newException(ValueError, "Database handle is nil")

  result.maps = initTable[string, MapHandle]()
  for cf in database.listColumnFamilies():
    result.maps[cf] = openMap(database, cf)

proc hasMap*(registry: DatabaseMapRegistry; columnFamily: string): bool =
  columnFamily in registry.maps

proc getMap*(registry: DatabaseMapRegistry; columnFamily: string): MapHandle =
  if columnFamily notin registry.maps:
    raise newException(KeyError, "Map was not found in registry")
  registry.maps[columnFamily]

proc mapNames*(registry: DatabaseMapRegistry): seq[string] =
  result = @[]
  for name in registry.maps.keys:
    result.add(name)

proc mapCount*(registry: DatabaseMapRegistry): int =
  registry.maps.len

proc closeRegistry*(registry: var DatabaseMapRegistry) =
  registry.maps.clear()

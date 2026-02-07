## Database module API for compatibility runtime.

import generated_column_families
import generated_column_family_descriptors
import types
import util
import serialization
import ser
import de
import keyval
import deserialized
import schema
import backend_memory
import backend_rocksdb
import db
import handle
import map
import stream
import maps
import cork
import engine
import pool
import tests

export generated_column_families
export generated_column_family_descriptors
export types
export util
export serialization
export ser
export de
export keyval
export deserialized
export schema
export backend_memory
export backend_rocksdb
export db
export handle
export map
export stream
export maps
export cork
export engine
export pool
export tests

type
  DatabaseModuleInfo* = object
    name*: string
    apiReady*: bool

proc databaseModuleInfo*(): DatabaseModuleInfo =
  DatabaseModuleInfo(name: "database", apiReady: true)

proc databaseApiReady*(): bool =
  databaseModuleInfo().apiReady

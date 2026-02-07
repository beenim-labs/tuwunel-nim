## Database engine API surface.

import engine/db_opts
import engine/cf_opts
import engine/descriptor
import engine/context
import engine/files
import engine/logger
import engine/memory_usage
import engine/open
import engine/repair
import engine/backup

export db_opts
export cf_opts
export descriptor
export context
export files
export logger
export memory_usage
export open
export repair
export backup

type
  EngineModuleInfo* = object
    name*: string
    hasBackup*: bool
    hasRepair*: bool

proc engineModuleInfo*(): EngineModuleInfo =
  EngineModuleInfo(name: "database.engine", hasBackup: true, hasRepair: true)

proc engineSupportsBackup*(): bool =
  engineModuleInfo().hasBackup

proc engineSupportsRepair*(): bool =
  engineModuleInfo().hasRepair

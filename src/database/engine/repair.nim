## Engine repair helpers.

import open
import context
import db_opts

type
  RepairReport* = object
    path*: string
    repairRequested*: bool
    openedReadOnly*: bool

proc repairAndOpen*(path: string; readOnlyAfterRepair = false): RepairReport =
  var options = defaultEngineDbOptions().withRepair(true)
  if readOnlyAfterRepair:
    options = options.withReadOnly(true)

  let context = initEngineContext(path, dbOptions = options)
  let opened = openEngine(context)
  if not opened.database.isNil:
    opened.database.close()

  RepairReport(path: path, repairRequested: true, openedReadOnly: readOnlyAfterRepair)

proc repairOnly*(path: string): RepairReport =
  repairAndOpen(path, readOnlyAfterRepair = true)

proc repairThenOpenWritable*(path: string): RepairReport =
  repairAndOpen(path, readOnlyAfterRepair = false)

proc repairWasReadOnly*(report: RepairReport): bool =
  report.openedReadOnly

proc repairWasRequested*(report: RepairReport): bool =
  report.repairRequested

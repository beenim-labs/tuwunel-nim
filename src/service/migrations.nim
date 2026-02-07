import database/[db, schema]
import service/config

const
  RustPath* = "service/migrations.rs"
  RustCrate* = "service"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  MigrationStep* = object
    id*: string
    description*: string
    required*: bool

  MigrationReport* = object
    ok*: bool
    applied*: seq[string]
    skipped*: seq[string]
    errors*: seq[string]

proc defaultMigrationSteps*(): seq[MigrationStep] =
  @[
    MigrationStep(
      id: "verify_required_column_families",
      description: "Validate required Matrix column-family schema compatibility",
      required: true,
    ),
    MigrationStep(
      id: "startup_netburst_flag",
      description: "Capture startup network burst gate state for runtime services",
      required: false,
    ),
  ]

proc runSchemaValidation(dbHandle: DatabaseHandle): tuple[ok: bool, err: string] =
  try:
    ensureRequiredSchemaCompatible(dbHandle.listColumnFamilies())
    (true, "")
  except CatchableError:
    (false, getCurrentExceptionMsg())

proc runServiceMigrations*(
    dbHandle: DatabaseHandle; runtimeConfig: ServiceRuntimeConfig): MigrationReport =
  result = MigrationReport(ok: true, applied: @[], skipped: @[], errors: @[])
  for step in defaultMigrationSteps():
    case step.id
    of "verify_required_column_families":
      let validated = runSchemaValidation(dbHandle)
      if validated.ok:
        result.applied.add(step.id)
      elif step.required:
        result.ok = false
        result.errors.add(step.id & ": " & validated.err)
      else:
        result.skipped.add(step.id)
    of "startup_netburst_flag":
      if runtimeConfig.startupNetburst:
        result.applied.add(step.id)
      else:
        result.skipped.add(step.id)
    else:
      if step.required:
        result.ok = false
        result.errors.add("Unknown required migration step: " & step.id)
      else:
        result.skipped.add(step.id)

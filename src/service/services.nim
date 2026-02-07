import std/[strutils, times]
import generated_service_inventory
import service/manager
import service/service

const
  RustPath* = "service/services.rs"
  RustCrate* = "service"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  ServicePlanItem* = object
    id*: string
    module*: string
    functionCount*: int
    dependencies*: seq[string]
    critical*: bool

proc normalizeModuleName(raw: string): string =
  result = raw
  if result.endsWith(".rs"):
    result.setLen(result.len - 3)
  result = result.replace("/", "_")
  result = result.replace(".", "_")

proc defaultDependencies(moduleId: string): seq[string] =
  case moduleId
  of "config":
    @[]
  of "globals":
    @["config"]
  of "resolver":
    @["config", "globals"]
  of "federation":
    @["resolver", "globals"]
  of "rooms":
    @["globals", "resolver"]
  of "users":
    @["globals"]
  of "client":
    @["users", "rooms"]
  of "sending":
    @["rooms", "resolver"]
  of "sync":
    @["rooms", "users"]
  else:
    @["globals"]

proc defaultServicePlan*(): seq[ServicePlanItem] =
  result = @[]
  for item in ServiceModuleCounts:
    let moduleId = normalizeModuleName(item.module)
    if moduleId.len == 0:
      continue
    result.add(
      ServicePlanItem(
        id: moduleId,
        module: moduleId,
        functionCount: item.functionCount,
        dependencies: defaultDependencies(moduleId),
        critical: true,
      )
    )

proc definitionFromPlan(item: ServicePlanItem): ServiceDefinition =
  var definition = initServiceDefinition(
    id = item.id,
    module = item.module,
    dependencies = item.dependencies,
    critical = item.critical,
  )

  let moduleName = item.module
  let functionCount = item.functionCount
  definition.onBuild = proc(ctx: ServiceContext): ServiceHookResult =
    ctx.incCounter("service.build.total")
    ctx.incCounter("service.build.functions", functionCount)
    ctx.setMeta(moduleName & ".built_at", $int64(getTime().toUnix()))
    hookOk()

  definition.onStart = proc(ctx: ServiceContext): ServiceHookResult =
    ctx.incCounter("service.start.total")
    ctx.setMeta(moduleName & ".started", "true")
    hookOk()

  definition.onPoll = proc(ctx: ServiceContext): ServiceHookResult =
    ctx.incCounter("service.poll.total")
    hookOk()

  definition.onInterrupt = proc(ctx: ServiceContext): ServiceHookResult =
    ctx.incCounter("service.interrupt.total")
    ctx.setMeta(moduleName & ".interrupted", "true")
    hookOk()

  definition.onStop = proc(ctx: ServiceContext): ServiceHookResult =
    ctx.incCounter("service.stop.total")
    ctx.setMeta(moduleName & ".stopped", "true")
    hookOk()

  definition

proc registerDefaultServices*(manager: ServiceManager): ServiceRegistrationReport =
  result = ServiceRegistrationReport(ok: true, registered: 0, errors: @[])
  for item in defaultServicePlan():
    let report = manager.registerService(definitionFromPlan(item))
    if not report.ok:
      result.ok = false
      for err in report.errors:
        result.errors.add(err)
      continue
    result.registered += report.registered

proc defaultServiceCount*(): int =
  defaultServicePlan().len

import std/[options, tables, times]
import core/config_values
import database/db

const
  RustPath* = "service/service.rs"
  RustCrate* = "service"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  ServicePhase* = enum
    spBuild
    spStart
    spPoll
    spInterrupt
    spStop

  ServiceState* = enum
    ssRegistered
    ssBuilt
    ssStarted
    ssInterrupted
    ssStopped
    ssFailed

  ServiceIssue* = object
    phase*: ServicePhase
    state*: ServiceState
    atUnix*: int64
    message*: string

  ServiceHookResult* = object
    ok*: bool
    err*: string

  ServiceContext* = ref object
    config*: FlatConfig
    database*: DatabaseHandle
    metadata*: Table[string, string]
    counters*: Table[string, int]

  ServiceHook* = proc(ctx: ServiceContext): ServiceHookResult {.closure.}

  ServiceDefinition* = object
    id*: string
    module*: string
    dependencies*: seq[string]
    critical*: bool
    onBuild*: ServiceHook
    onStart*: ServiceHook
    onPoll*: ServiceHook
    onInterrupt*: ServiceHook
    onStop*: ServiceHook

  ServiceRuntime* = object
    definition*: ServiceDefinition
    state*: ServiceState
    issues*: seq[ServiceIssue]
    phaseCount*: Table[ServicePhase, int]

proc hookOk*(): ServiceHookResult =
  ServiceHookResult(ok: true, err: "")

proc hookErr*(msg: string): ServiceHookResult =
  ServiceHookResult(ok: false, err: msg)

proc defaultHook(_: ServiceContext): ServiceHookResult =
  hookOk()

proc initServiceContext*(config: FlatConfig; database: DatabaseHandle): ServiceContext =
  new(result)
  result.config = config
  result.database = database
  result.metadata = initTable[string, string]()
  result.counters = initTable[string, int]()

proc setMeta*(ctx: ServiceContext; key, value: string) =
  ctx.metadata[key] = value

proc getMeta*(ctx: ServiceContext; key: string): Option[string] =
  if key in ctx.metadata:
    return some(ctx.metadata[key])
  none(string)

proc incCounter*(ctx: ServiceContext; key: string; by = 1) =
  let current = ctx.counters.getOrDefault(key, 0)
  ctx.counters[key] = current + by

proc counterValue*(ctx: ServiceContext; key: string): int =
  ctx.counters.getOrDefault(key, 0)

proc initServiceDefinition*(
    id, module: string; dependencies: seq[string] = @[]; critical = true): ServiceDefinition =
  ServiceDefinition(
    id: id,
    module: module,
    dependencies: dependencies,
    critical: critical,
    onBuild: defaultHook,
    onStart: defaultHook,
    onPoll: defaultHook,
    onInterrupt: defaultHook,
    onStop: defaultHook,
  )

proc initServiceRuntime*(definition: ServiceDefinition): ServiceRuntime =
  ServiceRuntime(
    definition: definition,
    state: ssRegistered,
    issues: @[],
    phaseCount: initTable[ServicePhase, int](),
  )

proc toState(phase: ServicePhase): ServiceState =
  case phase
  of spBuild: ssBuilt
  of spStart: ssStarted
  of spPoll: ssStarted
  of spInterrupt: ssInterrupted
  of spStop: ssStopped

proc runHook(runtime: ServiceRuntime; ctx: ServiceContext; phase: ServicePhase): ServiceHookResult =
  case phase
  of spBuild: runtime.definition.onBuild(ctx)
  of spStart: runtime.definition.onStart(ctx)
  of spPoll: runtime.definition.onPoll(ctx)
  of spInterrupt: runtime.definition.onInterrupt(ctx)
  of spStop: runtime.definition.onStop(ctx)

proc addIssue(runtime: var ServiceRuntime; phase: ServicePhase; message: string) =
  runtime.issues.add(
    ServiceIssue(
      phase: phase,
      state: runtime.state,
      atUnix: int64(getTime().toUnix()),
      message: message,
    )
  )

proc runPhase*(runtime: var ServiceRuntime; ctx: ServiceContext; phase: ServicePhase): ServiceHookResult =
  let n = runtime.phaseCount.getOrDefault(phase, 0)
  runtime.phaseCount[phase] = n + 1

  let outcome = runHook(runtime, ctx, phase)
  if not outcome.ok:
    runtime.state = ssFailed
    runtime.addIssue(phase, outcome.err)
    return outcome

  runtime.state = toState(phase)
  outcome

proc phaseRuns*(runtime: ServiceRuntime; phase: ServicePhase): int =
  runtime.phaseCount.getOrDefault(phase, 0)

proc failed*(runtime: ServiceRuntime): bool =
  runtime.state == ssFailed

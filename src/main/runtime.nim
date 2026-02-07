import std/strformat
import core/config_loader
import database/db
when defined(tuwunel_use_rocksdb):
  import database/backend_rocksdb
from service/config import ServiceRuntimeConfig, loadServiceRuntimeConfig
from service/globals import RuntimeGlobals, initRuntimeGlobals, setHealth, touchLifecycle
from service/service import ServiceContext, initServiceContext
from service/manager import ServiceManager, initServiceManager, serviceCount, buildAll, startAll, pollAll, interruptAll, stopAll
from service/services import registerDefaultServices
from service/once_services import OnceServiceGate, initOnceServiceGate
from service/migrations import MigrationReport, runServiceMigrations
from main/logging import buildLoggingPlan, applyLoggingPlan
from main/mods import enabledRuntimeMods
from main/restart import evaluateRestartDecision
from main/server import ServerHandle, loadServerConfig, initServerHandle, startServer, stopServer
from main/signals import RuntimeSignal, SignalController, initSignalController, dequeueSignal, rsNone, rsReload, rsInterrupt, rsTerminate

const
  RustPath* = "main/runtime.rs"
  RustCrate* = "main"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  RuntimeApp* = object
    loaded*: LoadedConfig
    runtimeConfig*: ServiceRuntimeConfig
    globals*: RuntimeGlobals
    manager*: ServiceManager
    onceGate*: OnceServiceGate
    server*: ServerHandle
    database*: DatabaseHandle
    migrations*: MigrationReport
    signalController*: SignalController
    enabledMods*: seq[string]
    started*: bool
    warnings*: seq[string]

  RuntimeRunReport* = object
    ok*: bool
    summary*: string
    err*: string

proc openRuntimeDatabase(
    runtimeConfig: ServiceRuntimeConfig): tuple[ok: bool, err: string, warning: string, db: DatabaseHandle] =
  if runtimeConfig.databasePath.len == 0 or runtimeConfig.databasePath == ":memory:":
    return (true, "", "", openInMemory())

  when defined(tuwunel_use_rocksdb):
    var options = defaultRocksDbOpenOptions()
    options.readOnly = runtimeConfig.readOnly
    options.secondary = runtimeConfig.secondary
    options.repair = runtimeConfig.repair
    options.neverDropColumns = runtimeConfig.neverDropColumns
    try:
      return (true, "", "", openRocksDb(runtimeConfig.databasePath, options))
    except CatchableError:
      return (false, getCurrentExceptionMsg(), "", nil)
  else:
    let warning = "rocksdb backend disabled at compile time, using in-memory database fallback"
    (true, "", warning, openInMemory())

proc bootstrapRuntime*(loaded: LoadedConfig): tuple[ok: bool, err: string, app: RuntimeApp] =
  let loggingPlan = buildLoggingPlan(loaded.values)
  applyLoggingPlan(loggingPlan)

  let runtimeConfig = loadServiceRuntimeConfig(loaded.values)
  let opened = openRuntimeDatabase(runtimeConfig)
  if not opened.ok:
    return (false, opened.err, RuntimeApp())

  let globals = initRuntimeGlobals(runtimeConfig.serverName)
  globals.setHealth("booting")
  let context = initServiceContext(loaded.values, opened.db)

  var manager = initServiceManager(context)
  let registration = registerDefaultServices(manager)
  if not registration.ok:
    opened.db.close()
    return (false, "service registration failed: " & $registration.errors, RuntimeApp())

  let migrations = runServiceMigrations(opened.db, runtimeConfig)
  if not migrations.ok:
    opened.db.close()
    return (false, "service migrations failed: " & $migrations.errors, RuntimeApp())

  let serverConfig = loadServerConfig(loaded.values)
  var warnings: seq[string] = @[]
  if opened.warning.len > 0:
    warnings.add(opened.warning)

  let enabledMods = enabledRuntimeMods(loaded.values)
  let app = RuntimeApp(
    loaded: loaded,
    runtimeConfig: runtimeConfig,
    globals: globals,
    manager: manager,
    onceGate: initOnceServiceGate(),
    server: initServerHandle(serverConfig),
    database: opened.db,
    migrations: migrations,
    signalController: initSignalController(),
    enabledMods: enabledMods,
    started: false,
    warnings: warnings,
  )

  (true, "", app)

proc startRuntime*(app: var RuntimeApp): tuple[ok: bool, err: string] =
  let build = app.manager.buildAll()
  if not build.ok:
    return (false, "service build failed: " & $build.errors)

  let start = app.manager.startAll()
  if not start.ok:
    return (false, "service start failed: " & $start.errors)

  let serverStart = app.server.startServer()
  if not serverStart.ok:
    return (false, serverStart.err)

  app.globals.setHealth("running")
  app.globals.touchLifecycle("start")
  app.started = true
  (true, "")

proc pollRuntime*(app: var RuntimeApp; cycles = 1): tuple[ok: bool, err: string, executed: int] =
  if not app.started:
    return (false, "runtime not started", 0)

  var completed = 0
  for _ in 0 ..< max(0, cycles):
    let poll = app.manager.pollAll()
    if not poll.ok:
      return (false, "service poll failed: " & $poll.errors, completed)
    inc completed

    let signal = app.signalController.dequeueSignal()
    case signal
    of rsNone:
      discard
    of rsReload:
      app.globals.touchLifecycle("reload")
    of rsInterrupt, rsTerminate:
      break

  (true, "", completed)

proc shutdownRuntime*(app: var RuntimeApp): tuple[ok: bool, err: string] =
  if not app.started:
    if not app.database.isNil:
      app.database.close()
    return (true, "")

  let interrupted = app.manager.interruptAll()
  if not interrupted.ok:
    return (false, "service interrupt failed: " & $interrupted.errors)

  let stopped = app.manager.stopAll()
  if not stopped.ok:
    return (false, "service stop failed: " & $stopped.errors)

  discard app.server.stopServer()
  app.database.close()
  app.started = false
  app.globals.setHealth("stopped")
  app.globals.touchLifecycle("stop")
  (true, "")

proc runtimeSummary*(app: RuntimeApp): string =
  let restartDecision = evaluateRestartDecision(app.loaded.values)
  let restartSummary =
    if restartDecision.requested: "restart=requested"
    else: "restart=none"
  let warningSummary =
    if app.warnings.len == 0: "warnings=0"
    else: "warnings=" & $app.warnings.len

  fmt"mods={app.enabledMods.len} services={app.manager.serviceCount()} migrations_ok={app.migrations.ok} {restartSummary} {warningSummary}"

proc runRuntimeCycle*(loaded: LoadedConfig; cycles = 1): RuntimeRunReport =
  let boot = bootstrapRuntime(loaded)
  if not boot.ok:
    return RuntimeRunReport(ok: false, err: boot.err, summary: "")

  var app = boot.app
  let started = startRuntime(app)
  if not started.ok:
    discard shutdownRuntime(app)
    return RuntimeRunReport(ok: false, err: started.err, summary: "")

  let polled = pollRuntime(app, cycles = cycles)
  if not polled.ok:
    discard shutdownRuntime(app)
    return RuntimeRunReport(ok: false, err: polled.err, summary: "")

  let stopped = shutdownRuntime(app)
  if not stopped.ok:
    return RuntimeRunReport(ok: false, err: stopped.err, summary: "")

  RuntimeRunReport(ok: true, err: "", summary: app.runtimeSummary())

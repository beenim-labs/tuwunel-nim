import core/config_loader
import main/args
import main/runtime

const
  RustPath* = "main/tests/smoke_shutdown.rs"
  RustCrate* = "main"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  ShutdownSmokeResult* = object
    booted*: bool
    started*: bool
    shutdownOk*: bool
    err*: string

proc runShutdownSmoke*(): ShutdownSmokeResult =
  let parsed = parseArgs(@["-O", "database_path=\":memory:\""])
  let loaded = loadConfigCompatibility(parsed)
  if not loaded.ok:
    return ShutdownSmokeResult(booted: false, started: false, shutdownOk: false, err: loaded.err)

  let boot = bootstrapRuntime(loaded.cfg)
  if not boot.ok:
    return ShutdownSmokeResult(booted: false, started: false, shutdownOk: false, err: boot.err)

  var app = boot.app
  let started = startRuntime(app)
  if not started.ok:
    discard shutdownRuntime(app)
    return ShutdownSmokeResult(booted: true, started: false, shutdownOk: false, err: started.err)

  let shutdown = shutdownRuntime(app)
  ShutdownSmokeResult(
    booted: true,
    started: true,
    shutdownOk: shutdown.ok,
    err: shutdown.err,
  )

proc shutdownSmokePassed*(result: ShutdownSmokeResult): bool =
  result.booted and result.started and result.shutdownOk

proc shutdownSmokeSummaryLine*(result: ShutdownSmokeResult): string =
  "booted=" & $result.booted & " started=" & $result.started & " shutdown=" & $result.shutdownOk & " err=" & result.err

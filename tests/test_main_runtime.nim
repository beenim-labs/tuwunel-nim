import std/unittest
import main/args
import main/runtime
import core/config_loader

suite "Main runtime compatibility":
  test "bootstrap start poll stop":
    let parsed = parseArgs(@[
      "--maintenance",
      "-O",
      "database_path=\":memory:\"",
    ])
    let loaded = loadConfigCompatibility(parsed)
    check loaded.ok

    let boot = bootstrapRuntime(loaded.cfg)
    check boot.ok

    var app = boot.app
    let started = startRuntime(app)
    check started.ok

    let polled = pollRuntime(app, cycles = 2)
    check polled.ok
    check polled.executed == 2

    let stopped = shutdownRuntime(app)
    check stopped.ok

  test "run cycle helper":
    let parsed = parseArgs(@[
      "-O",
      "database_path=\":memory:\"",
    ])
    let loaded = loadConfigCompatibility(parsed)
    check loaded.ok

    let report = runRuntimeCycle(loaded.cfg, cycles = 1)
    check report.ok
    check report.summary.len > 0

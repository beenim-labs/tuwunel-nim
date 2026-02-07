import std/unittest
import core/config_values
import database/db
import service/config
import service/globals
import service/manager
import service/migrations
import service/once_services
import service/service
import service/services

suite "Service runtime lifecycle":
  test "runtime config extraction":
    var values = initFlatConfig()
    values["server_name"] = newStringValue("example.com")
    values["database_path"] = newStringValue(":memory:")
    values["rocksdb_read_only"] = newBoolValue(true)
    values["listening"] = newBoolValue(false)
    values["admin_execute"] = newArrayValue(@[newStringValue("users create_user alice")])

    let cfg = loadServiceRuntimeConfig(values)
    check cfg.serverName == "example.com"
    check cfg.databasePath == ":memory:"
    check cfg.readOnly
    check not cfg.listening
    check cfg.adminExecute.len == 1

  test "manager registration and lifecycle phases":
    var values = initFlatConfig()
    values["server_name"] = newStringValue("example.com")

    let cfg = loadServiceRuntimeConfig(values)
    let globals = initRuntimeGlobals(cfg.serverName)
    check globals.serverName == "example.com"

    let dbHandle = openInMemory()
    let ctx = initServiceContext(values, dbHandle)

    var manager = initServiceManager(ctx)
    let registration = registerDefaultServices(manager)
    check registration.ok
    check registration.registered == defaultServiceCount()

    let built = manager.buildAll()
    check built.ok

    let started = manager.startAll()
    check started.ok

    let polled = manager.pollAll()
    check polled.ok

    let interrupted = manager.interruptAll()
    check interrupted.ok

    let stopped = manager.stopAll()
    check stopped.ok

    dbHandle.close()

  test "once gate and migrations":
    let dbHandle = openInMemory()
    let cfg = loadServiceRuntimeConfig(initFlatConfig())

    let migrationReport = runServiceMigrations(dbHandle, cfg)
    check migrationReport.ok

    var gate = initOnceServiceGate()
    var runs = 0
    let first = gate.runOnce("bootstrap", proc(): bool =
      inc runs
      true
    )
    check first

    let second = gate.runOnce("bootstrap", proc(): bool =
      inc runs
      true
    )
    check second
    check runs == 1
    check gate.hasCompleted("bootstrap")

    dbHandle.close()

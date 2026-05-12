import std/unittest

import service/globals/data as globals_data
import "service/globals/mod" as globals_service

suite "Service globals parity":
  test "global data counter dispatches retires and stores database version":
    var data = globals_data.initGlobalData(storedCount = 7'u64, databaseVersion = 1'u64)
    check globals_data.currentCount(data) == 7'u64
    check globals_data.waitPending(data) == 7'u64

    let permit = globals_data.nextCount(data)
    check permit.count == 8'u64
    check permit.retired
    check globals_data.currentCount(data) == 8'u64
    check globals_data.waitCount(data, 8'u64).ok

    globals_data.bumpDatabaseVersion(data, 2'u64)
    check globals_data.databaseVersion(data) == 2'u64

  test "globals service exposes server identity and local checks":
    var service = globals_service.initGlobalsService("example.test", storedCount = 1'u64, turnSecret = "secret")
    check service.serverUser == "@conduit:example.test"
    check service.turnSecret == "secret"
    check globals_service.serverNameValue(service) == "example.test"
    check globals_service.userIsLocal(service, "@alice:example.test")
    check not globals_service.userIsLocal(service, "@alice:elsewhere.test")
    check globals_service.aliasIsLocal(service, "#room:example.test")
    check globals_service.serverIsOurs(service, "example.test")
    check not globals_service.isReadOnly(service)
    check globals_service.initRustlsProvider(service)

    let permit = globals_service.nextCount(service)
    check permit.count == 2'u64
    check globals_service.currentCount(service) == 2'u64

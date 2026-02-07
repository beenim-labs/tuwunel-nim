import std/[os, unittest]
import database/[db, engine, pool, tests]
import database/pool/configure

suite "Database engine and pool wrappers":
  test "engine option mapping and context selection":
    let options = defaultEngineDbOptions().withReadOnly(true).withRepair(true)
    let rocks = options.toRocksDbOpenOptions()
    check rocks.readOnly
    check rocks.repair

    let context = initEngineContext("/tmp/tuwunel_engine_ctx")
    check context.path.len > 0
    check context.selectedDescriptors().len > 0

  test "engine backup report generation":
    let base = getTempDir() / "tuwunel_nim_engine_backup"
    if dirExists(base):
      removeDir(base)

    let context = initEngineContext(base)
    let report = createBackup(context, base)
    check report.backupPath.len > 0
    check fileExists(report.backupPath / "backup_manifest.json")

  test "engine memory usage report":
    let d = openInMemory()
    d.put("global", @[byte('a')], @[byte('b')])
    let usage = estimateMemoryUsage(d)
    check usage.columnFamilies > 0
    check usage.totalKeys >= 1

  test "pool borrow and release":
    let d = openInMemory()
    let p = newDbPool(d, defaultDbPoolConfig().withWorkers(2).withMaxWorkers(3))
    let h1 = p.borrow()
    let h2 = p.borrow()
    check not h1.isNil
    check not h2.isNil
    check not p.isSaturated()
    p.release()
    p.release()
    check p.queueCapacity() > 0

  test "database self checks":
    check runInMemorySelfCheck()
    check runSchemaCheck()

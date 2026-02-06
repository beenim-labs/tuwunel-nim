import std/[json, unittest]

proc loadJson(path: string): JsonNode =
  parseJson(readFile(path))

suite "Behavior coverage artifacts":
  test "report totals align with baseline inventory":
    let baseline = loadJson("docs/parity/baseline.json")
    let moduleCoverage = loadJson("docs/parity/module_coverage.json")
    let implementation = loadJson("docs/parity/implementation_coverage.json")
    let routeBehavior = loadJson("docs/parity/route_behavior_coverage.json")
    let configBehavior = loadJson("docs/parity/config_behavior_coverage.json")

    check implementation["total_modules"].getInt() == moduleCoverage["mapped"].getInt()
    check routeBehavior["summary"]["total_routes"].getInt() == baseline["totals"]["route_total"].getInt()
    check configBehavior["summary"]["total_keys"].getInt() == baseline["totals"]["config_field_total"].getInt()

  test "threshold booleans are exposed for milestone gating":
    let implementation = loadJson("docs/parity/implementation_coverage.json")
    let routeBehavior = loadJson("docs/parity/route_behavior_coverage.json")
    let configBehavior = loadJson("docs/parity/config_behavior_coverage.json")

    check implementation["thresholds"]["all_modules_implemented"].kind == JBool
    check implementation["thresholds"]["database_modules_implemented"].kind == JBool
    check routeBehavior["thresholds"]["all_routes_registered"].kind == JBool
    check routeBehavior["thresholds"]["all_routes_behavioral"].kind == JBool
    check configBehavior["thresholds"]["m2_ready"].kind == JBool

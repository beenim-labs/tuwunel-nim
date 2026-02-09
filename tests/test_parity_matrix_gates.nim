import std/[json, strutils, unittest]

proc loadJson(path: string): JsonNode =
  parseJson(readFile(path))

proc milestoneStatus(md, milestone: string): string =
  let needle = "| " & milestone & " |"
  for raw in md.splitLines():
    let line = raw.strip()
    if not line.startsWith(needle):
      continue
    let parts = line.split("|")
    if parts.len >= 4:
      return parts[2].strip()
  ""

suite "Parity matrix status gating":
  test "M1/M2/M3/M4 statuses are derived from coverage thresholds":
    let moduleCoverage = loadJson("docs/parity/module_coverage.json")
    let implementation = loadJson("docs/parity/implementation_coverage.json")
    let configBehavior = loadJson("docs/parity/config_behavior_coverage.json")
    let runtimeDiff = loadJson("docs/parity/runtime_diff_report.json")
    let md = readFile("docs/parity_matrix.md")

    let expectedM1 =
      if moduleCoverage["mapped"].getInt() > 0 and moduleCoverage["missing"].getInt() == 0:
        "Implemented"
      else:
        "In progress"
    let expectedM2 =
      if configBehavior["thresholds"]["m2_ready"].getBool():
        "Implemented"
      else:
        "In progress"
    let expectedM3 =
      if implementation["thresholds"]["database_modules_implemented"].getBool():
        "Implemented"
      else:
        "In progress"
    let expectedM4 =
      if runtimeDiff["scenarios_total"].getInt() > 0 and
          runtimeDiff["mismatches_total"].getInt() == 0 and
          runtimeDiff["skipped_total"].getInt() == 0:
        "Implemented"
      else:
        "In progress"

    check milestoneStatus(md, "M1 inventory + codegen") == expectedM1
    check milestoneStatus(md, "M2 core runtime/CLI/config parity") == expectedM2
    check milestoneStatus(md, "M3 database compatibility") == expectedM3
    check milestoneStatus(md, "M4+") == expectedM4

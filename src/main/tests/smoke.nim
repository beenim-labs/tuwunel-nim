import core/config_loader
import main/args
import main/runtime

const
  RustPath* = "main/tests/smoke.rs"
  RustCrate* = "main"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  SmokeResult* = object
    ok*: bool
    err*: string
    summary*: string

proc runSmoke*(): SmokeResult =
  let parsed = parseArgs(@["-O", "database_path=\":memory:\""])
  let loaded = loadConfigCompatibility(parsed)
  if not loaded.ok:
    return SmokeResult(ok: false, err: loaded.err, summary: "")

  let report = runRuntimeCycle(loaded.cfg, cycles = 1)
  SmokeResult(ok: report.ok, err: report.err, summary: report.summary)

proc smokePassed*(result: SmokeResult): bool =
  result.ok

proc smokeSummaryLine*(result: SmokeResult): string =
  "ok=" & $result.ok & " err=" & result.err & " summary=" & result.summary

proc runSmokeCycles*(cycles = 2): SmokeResult =
  var last = SmokeResult(ok: true, err: "", summary: "")
  for _ in 0 ..< max(1, cycles):
    let current = runSmoke()
    if not current.ok:
      return current
    last = current
  last

proc smokeHealthy*(result: SmokeResult): bool =
  result.ok and result.err.len == 0

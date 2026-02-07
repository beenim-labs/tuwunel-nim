import core/config_loader
import runtime

const
  RustPath* = "main/lib.rs"
  RustCrate* = "main"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  CompatibilityRuntimeResult* = object
    ok*: bool
    err*: string
    summary*: string

  CompatibilityRunOptions* = object
    cycles*: int
    failFast*: bool

proc runCompatibilityRuntime*(loaded: LoadedConfig; cycles = 1): CompatibilityRuntimeResult =
  let report = runRuntimeCycle(loaded, cycles = cycles)
  CompatibilityRuntimeResult(
    ok: report.ok,
    err: report.err,
    summary: report.summary,
  )

proc defaultCompatibilityRunOptions*(): CompatibilityRunOptions =
  CompatibilityRunOptions(cycles: 1, failFast: true)

proc runCompatibilityRuntimeWithOptions*(
    loaded: LoadedConfig; options = defaultCompatibilityRunOptions()): CompatibilityRuntimeResult =
  var cycleCount = options.cycles
  if cycleCount < 1:
    cycleCount = 1

  let runResult = runCompatibilityRuntime(loaded, cycles = cycleCount)
  if options.failFast and not runResult.ok:
    return runResult
  runResult

proc compatibilitySummaryLine*(result: CompatibilityRuntimeResult): string =
  "ok=" & $result.ok & " err=" & result.err & " summary=" & result.summary

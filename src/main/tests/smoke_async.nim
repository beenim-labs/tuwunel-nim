import std/times
import main/tests/smoke

const
  RustPath* = "main/tests/smoke_async.rs"
  RustCrate* = "main"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  AsyncSmokeResult* = object
    ok*: bool
    durationMs*: int64
    summary*: string

proc runSmokeAsyncLike*(cycles = 2): AsyncSmokeResult =
  let start = getTime()
  var ok = true
  var summary = ""

  for _ in 0 ..< max(1, cycles):
    let smoke = runSmoke()
    if not smoke.ok:
      ok = false
      summary = smoke.err
      break
    summary = smoke.summary

  let elapsed = (getTime() - start).inMilliseconds
  AsyncSmokeResult(ok: ok, durationMs: elapsed, summary: summary)

proc asyncSmokePassed*(result: AsyncSmokeResult): bool =
  result.ok

proc asyncSmokeSummaryLine*(result: AsyncSmokeResult): string =
  "ok=" & $result.ok & " duration_ms=" & $result.durationMs & " summary=" & result.summary

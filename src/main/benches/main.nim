import std/times

const
  RustPath* = "main/benches/main.rs"
  RustCrate* = "main"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  BenchSample* = object
    name*: string
    iterations*: int
    elapsedMs*: int64

  BenchReport* = object
    samples*: seq[BenchSample]

proc runTimed*(name: string; iterations: int; body: proc() {.closure.}): BenchSample =
  let start = getTime()
  for _ in 0 ..< max(1, iterations):
    body()
  let elapsed = (getTime() - start).inMilliseconds
  BenchSample(name: name, iterations: max(1, iterations), elapsedMs: elapsed)

proc addSample*(report: var BenchReport; sample: BenchSample) =
  report.samples.add(sample)

proc sampleCount*(report: BenchReport): int =
  report.samples.len

proc totalElapsedMs*(report: BenchReport): int64 =
  result = 0
  for sample in report.samples:
    result += sample.elapsedMs

proc benchmarkSummaryLine*(report: BenchReport): string =
  "samples=" & $report.sampleCount() & " elapsed_ms=" & $report.totalElapsedMs()

proc runBenchSmoke*(): BenchReport =
  var report = BenchReport(samples: @[])
  report.addSample(runTimed("noop", 1000, proc() = discard))
  report

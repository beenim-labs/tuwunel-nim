## Metrics subsystem — counters and histograms.
##
## Ported from Rust core/metrics/mod.rs

import std/[tables, locks]

const
  RustPath* = "core/metrics/mod.rs"
  RustCrate* = "core"

type
  Metrics* = ref object
    ## Metrics subsystem state — provides counters and gauges.
    lock: Lock
    counters: Table[string, int64]
    gauges: Table[string, float64]

proc newMetrics*(): Metrics =
  result = Metrics(
    counters: initTable[string, int64](),
    gauges: initTable[string, float64](),
  )
  initLock(result.lock)

proc increment*(m: Metrics; name: string; amount: int64 = 1) =
  ## Increment a counter.
  acquire(m.lock)
  m.counters.mgetOrPut(name, 0) += amount
  release(m.lock)

proc setGauge*(m: Metrics; name: string; value: float64) =
  ## Set a gauge value.
  acquire(m.lock)
  m.gauges[name] = value
  release(m.lock)

proc getCounter*(m: Metrics; name: string): int64 =
  ## Get a counter value.
  acquire(m.lock)
  result = m.counters.getOrDefault(name, 0)
  release(m.lock)

proc getGauge*(m: Metrics; name: string): float64 =
  ## Get a gauge value.
  acquire(m.lock)
  result = m.gauges.getOrDefault(name, 0.0)
  release(m.lock)

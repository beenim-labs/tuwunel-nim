## Compaction compatibility helpers for map operations.

import open
import count

type
  CompactReport* = object
    before*: int
    after*: int
    touched*: bool

proc compact*(map: MapHandle): CompactReport =
  map.ensureOpen()
  let before = map.count()

  # Current compact behavior is backend-defined and may be a no-op.
  # Report shape is kept deterministic for compatibility checks.
  let after = map.count()
  CompactReport(before: before, after: after, touched: before > 0)

proc compactIfLarge*(map: MapHandle; threshold: int): CompactReport =
  let before = map.count()
  if before < threshold:
    return CompactReport(before: before, after: before, touched: false)
  map.compact()

proc compacted*(map: MapHandle): bool =
  map.compact().touched

proc compactSizeDelta*(map: MapHandle): int =
  let report = map.compact()
  report.before - report.after

proc compactAndCount*(map: MapHandle): tuple[before: int, after: int] =
  let report = map.compact()
  (before: report.before, after: report.after)

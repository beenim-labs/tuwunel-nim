## Memory usage estimation helpers.

import ../db

type
  MemoryUsageReport* = object
    columnFamilies*: int
    totalKeys*: int
    approxBytes*: int

proc estimateMemoryUsage*(database: DatabaseHandle): MemoryUsageReport =
  let families = database.listColumnFamilies()

  var keyCount = 0
  var bytesTotal = 0
  for family in families:
    for entry in database.entries(family):
      inc keyCount
      bytesTotal += entry.key.len
      bytesTotal += entry.value.len

  MemoryUsageReport(
    columnFamilies: families.len,
    totalKeys: keyCount,
    approxBytes: bytesTotal,
  )

proc isLargeUsage*(report: MemoryUsageReport; thresholdBytes: int): bool =
  report.approxBytes >= thresholdBytes

proc averageBytesPerKey*(report: MemoryUsageReport): float =
  if report.totalKeys == 0:
    return 0.0
  report.approxBytes.float / report.totalKeys.float

proc hasData*(report: MemoryUsageReport): bool =
  report.totalKeys > 0

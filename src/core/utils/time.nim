## Time utilities — epoch helpers, duration formatting, pretty printing.
##
## Ported from Rust core/utils/time.rs

import std/[times, strformat, strutils, math]

const
  RustPath* = "core/utils/time.rs"
  RustCrate* = "core"

type
  TimeUnit* = enum
    tuDays, tuHours, tuMins, tuSecs, tuMillis, tuMicros, tuNanos

  WholeUnit* = object
    unit*: TimeUnit
    value*: uint64

proc nowMillis*(): uint64 =
  ## Current time as milliseconds since Unix epoch.
  uint64(epochTime() * 1000.0)

proc nowSecs*(): uint64 =
  ## Current time as seconds since Unix epoch.
  uint64(epochTime())

proc now*(): Duration =
  ## Duration since Unix epoch.
  initDuration(milliseconds = int64(epochTime() * 1000.0))

proc durationSinceEpoch*(t: Time): Duration =
  ## Duration from epoch to the given timepoint.
  t - fromUnix(0)

proc timepointFromEpoch*(d: Duration): Time =
  ## Create a Time from a duration since epoch.
  fromUnix(0) + d

proc timepointFromNow*(d: Duration): Time =
  ## Create a Time that is `d` from now.
  getTime() + d

proc timepointAgo*(d: Duration): Time =
  ## Create a Time that is `d` before now.
  getTime() - d

proc timepointHasPassed*(t: Time): bool =
  ## Check whether a timepoint has passed.
  getTime() > t

proc rfc2822FromSeconds*(epoch: int64): string =
  ## Format an epoch timestamp as RFC 2822.
  let t = fromUnix(epoch)
  t.utc.format("ddd, dd MMM yyyy HH:mm:ss") & " +0000"

proc formatTime*(t: Time; fmt: string): string =
  ## Format a Time using the given format string.
  t.utc.format(fmt)

proc wholeUnit*(secs: uint64; nanos: uint32): WholeUnit =
  ## Return the largest unit which represents the duration. The value
  ## is rounded-down, but never zero.
  if secs >= 86_400:
    WholeUnit(unit: tuDays, value: secs div 86_400)
  elif secs >= 3_600:
    WholeUnit(unit: tuHours, value: secs div 3_600)
  elif secs >= 60:
    WholeUnit(unit: tuMins, value: secs div 60)
  elif secs >= 1:
    WholeUnit(unit: tuSecs, value: secs)
  elif nanos >= 1_000_000:
    WholeUnit(unit: tuMillis, value: uint64(nanos div 1_000_000))
  elif nanos >= 1_000:
    WholeUnit(unit: tuMicros, value: uint64(nanos div 1_000))
  else:
    WholeUnit(unit: tuNanos, value: uint64(nanos))

proc prettyDuration*(d: Duration): string =
  ## Format a Duration into a human-readable string like "1.50 hours".
  let parts = d.toParts()
  let totalSecs = uint64(max(0, int64(d.inSeconds)))
  let nanos = uint32(max(0, parts[Nanoseconds]))
  let wu = wholeUnit(totalSecs, nanos)
  let frac = case wu.unit
    of tuDays: float64(totalSecs mod 86_400) / 86_400.0
    of tuHours: float64(totalSecs mod 3_600) / 3_600.0
    of tuMins: float64(totalSecs mod 60) / 60.0
    of tuSecs: float64(nanos mod 1_000_000_000) / 1_000_000_000.0
    of tuMillis: float64(nanos mod 1_000_000) / 1_000_000.0
    of tuMicros: float64(nanos mod 1_000) / 1_000.0
    of tuNanos: 0.0
  let fracInt = uint32(frac * 100.0)
  let unitName = case wu.unit
    of tuDays: "days"
    of tuHours: "hours"
    of tuMins: "minutes"
    of tuSecs: "seconds"
    of tuMillis: "milliseconds"
    of tuMicros: "microseconds"
    of tuNanos: "nanoseconds"
  &"{wu.value}.{fracInt} {unitName}"

proc parseDuration*(s: string): Duration =
  ## Parse a human-readable duration string (e.g., "5s", "2m", "1h", "3d").
  if s.len == 0:
    raise newException(ValueError, "empty duration string")
  var numStr = ""
  var unitStr = ""
  for ch in s:
    if ch in '0'..'9' or ch == '.':
      numStr.add ch
    else:
      unitStr.add ch
  unitStr = unitStr.strip().toLowerAscii()
  let val = parseFloat(numStr)
  case unitStr
  of "s", "sec", "secs", "second", "seconds":
    initDuration(milliseconds = int64(val * 1000.0))
  of "m", "min", "mins", "minute", "minutes":
    initDuration(seconds = int64(val * 60.0))
  of "h", "hr", "hrs", "hour", "hours":
    initDuration(seconds = int64(val * 3600.0))
  of "d", "day", "days":
    initDuration(seconds = int64(val * 86400.0))
  of "w", "week", "weeks":
    initDuration(seconds = int64(val * 604800.0))
  of "ms", "millis", "millisecond", "milliseconds":
    initDuration(milliseconds = int64(val))
  of "us", "micros", "microsecond", "microseconds":
    initDuration(microseconds = int64(val))
  of "ns", "nanos", "nanosecond", "nanoseconds":
    initDuration(nanoseconds = int64(val))
  else:
    raise newException(ValueError, &"unknown duration unit: '{unitStr}'")

proc parseTimepointAgo*(ago: string): Time =
  ## Parse a duration string and return the timepoint that was that long ago.
  timepointAgo(parseDuration(ago))

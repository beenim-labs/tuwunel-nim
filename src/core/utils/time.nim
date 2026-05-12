import std/[strutils, times]

const
  RustPath* = "core/utils/time.rs"
  RustCrate* = "core"

type
  Duration* = object
    nanos*: uint64

  Timepoint* = object
    unixNanos*: int64

  UnitKind* = enum
    ukDays, ukHours, ukMins, ukSecs, ukMillis, ukMicros, ukNanos

  Unit* = object
    kind*: UnitKind
    whole*: uint64

  DurationResult* = tuple[ok: bool, duration: Duration, message: string]
  TimepointResult* = tuple[ok: bool, timepoint: Timepoint, message: string]

const
  NanosPerMicro = 1_000'u64
  NanosPerMilli = 1_000_000'u64
  NanosPerSec = 1_000_000_000'u64
  NanosPerMin = 60'u64 * NanosPerSec
  NanosPerHour = 60'u64 * NanosPerMin
  NanosPerDay = 24'u64 * NanosPerHour

proc durationFromNanos*(nanos: uint64): Duration =
  Duration(nanos: nanos)

proc durationFromMicros*(micros: uint64): Duration =
  Duration(nanos: micros * NanosPerMicro)

proc durationFromMillis*(millis: uint64): Duration =
  Duration(nanos: millis * NanosPerMilli)

proc durationFromSecs*(secs: uint64): Duration =
  Duration(nanos: secs * NanosPerSec)

proc asSecs*(duration: Duration): uint64 =
  duration.nanos div NanosPerSec

proc asMillis*(duration: Duration): uint64 =
  duration.nanos div NanosPerMilli

proc asMicros*(duration: Duration): uint64 =
  duration.nanos div NanosPerMicro

proc asNanos*(duration: Duration): uint64 =
  duration.nanos

proc subsecMillis(duration: Duration): uint64 =
  (duration.nanos mod NanosPerSec) div NanosPerMilli

proc subsecMicros(duration: Duration): uint64 =
  (duration.nanos mod NanosPerSec) div NanosPerMicro

proc subsecNanos(duration: Duration): uint64 =
  duration.nanos mod NanosPerSec

proc now*(): Duration =
  let secs = epochTime()
  if secs <= 0.0:
    return durationFromNanos(0)
  durationFromNanos(uint64(secs * 1_000_000_000.0))

proc nowMillis*(): uint64 =
  now().asMillis()

proc nowSecs*(): uint64 =
  now().asSecs()

proc durationSinceEpoch*(timepoint: Timepoint): Duration =
  if timepoint.unixNanos <= 0:
    durationFromNanos(0)
  else:
    durationFromNanos(uint64(timepoint.unixNanos))

proc timepointFromEpoch*(duration: Duration): TimepointResult =
  if duration.nanos > uint64(high(int64)):
    return (false, Timepoint(), "Duration from epoch is too large")
  (true, Timepoint(unixNanos: int64(duration.nanos)), "")

proc timepointFromNow*(duration: Duration): TimepointResult =
  let base = now().nanos
  if duration.nanos > high(uint64) - base:
    return (false, Timepoint(), "Duration from now is too large")
  let target = base + duration.nanos
  if target > uint64(high(int64)):
    return (false, Timepoint(), "Duration from now is too large")
  (true, Timepoint(unixNanos: int64(target)), "")

proc timepointAgo*(duration: Duration): TimepointResult =
  let base = now().nanos
  if duration.nanos > base:
    return (false, Timepoint(), "Duration ago is too large")
  (true, Timepoint(unixNanos: int64(base - duration.nanos)), "")

proc parseDuration*(raw: string): DurationResult =
  let value = raw.strip()
  if value.len == 0:
    return (false, Duration(), "'" & raw & "' is not a valid duration string")

  var numberEnd = 0
  while numberEnd < value.len and value[numberEnd] in {'0'..'9'}:
    inc numberEnd
  if numberEnd == 0:
    return (false, Duration(), "'" & raw & "' is not a valid duration string")

  let amount = parseUInt(value[0 ..< numberEnd])
  let unit = value[numberEnd .. ^1].strip().toLowerAscii()
  case unit
  of "d", "day", "days":
    (true, durationFromNanos(amount * NanosPerDay), "")
  of "h", "hr", "hour", "hours":
    (true, durationFromNanos(amount * NanosPerHour), "")
  of "m", "min", "minute", "minutes":
    (true, durationFromNanos(amount * NanosPerMin), "")
  of "s", "sec", "second", "seconds":
    (true, durationFromSecs(amount), "")
  of "ms", "millisecond", "milliseconds":
    (true, durationFromMillis(amount), "")
  of "us", "microsecond", "microseconds":
    (true, durationFromMicros(amount), "")
  of "ns", "nanosecond", "nanoseconds":
    (true, durationFromNanos(amount), "")
  else:
    (false, Duration(), "'" & raw & "' is not a valid duration string")

proc parseTimepointAgo*(raw: string): TimepointResult =
  let parsed = parseDuration(raw)
  if not parsed.ok:
    return (false, Timepoint(), parsed.message)
  timepointAgo(parsed.duration)

proc timepointHasPassed*(timepoint: Timepoint): bool =
  timepoint.unixNanos <= int64(now().nanos)

proc rfc2822FromSeconds*(epoch: int64): string =
  fromUnix(epoch).utc.format("ddd, dd MMM yyyy HH:mm:ss '+0000'")

proc format*(timepoint: Timepoint; layout: string): string =
  fromUnix(timepoint.unixNanos div int64(NanosPerSec)).utc.format(layout)

proc wholeUnit*(duration: Duration): Unit =
  let secs = duration.asSecs()
  if secs >= 86_400'u64:
    Unit(kind: ukDays, whole: secs div 86_400'u64)
  elif secs >= 3_600'u64:
    Unit(kind: ukHours, whole: secs div 3_600'u64)
  elif secs >= 60'u64:
    Unit(kind: ukMins, whole: secs div 60'u64)
  elif duration.asMicros() >= 1_000_000'u64:
    Unit(kind: ukSecs, whole: secs)
  elif duration.asMicros() >= 1_000'u64:
    Unit(kind: ukMillis, whole: subsecMillis(duration))
  elif duration.asNanos() >= 1_000'u64:
    Unit(kind: ukMicros, whole: subsecMicros(duration))
  else:
    Unit(kind: ukNanos, whole: subsecNanos(duration))

proc wholeAndFrac*(duration: Duration): tuple[unit: Unit, frac: float] =
  let unit = wholeUnit(duration)
  let frac =
    case unit.kind
    of ukDays: float(duration.asSecs() mod 86_400'u64) / 86_400.0
    of ukHours: float(duration.asSecs() mod 3_600'u64) / 3_600.0
    of ukMins: float(duration.asSecs() mod 60'u64) / 60.0
    of ukSecs: float(subsecMillis(duration)) / 1_000.0
    of ukMillis: float(subsecMicros(duration)) / 1_000.0
    of ukMicros: float(subsecNanos(duration)) / 1_000.0
    of ukNanos: 0.0
  (unit, frac)

proc pretty*(duration: Duration): string =
  let (unit, frac) = wholeAndFrac(duration)
  let suffix =
    case unit.kind
    of ukDays: "days"
    of ukHours: "hours"
    of ukMins: "minutes"
    of ukSecs: "seconds"
    of ukMillis: "milliseconds"
    of ukMicros: "microseconds"
    of ukNanos: "nanoseconds"
  $unit.whole & "." & $(uint64(frac * 100.0)) & " " & suffix

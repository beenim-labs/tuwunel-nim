import std/[options, os, osproc, parseutils, strutils]

type
  Args* = object
    config*: seq[string]
    option*: seq[string]
    readOnly*: bool
    maintenance*: bool
    console*: bool
    execute*: seq[string]
    test*: seq[string]
    bench*: seq[string]
    workerThreads*: int
    globalEventInterval*: int
    kernelEventInterval*: int
    kernelEventsPerTick*: int
    workerHistogramInterval*: int
    workerHistogramBuckets*: int
    workerAffinity*: bool
    gcOnPark*: Option[bool]
    gcMuzzy*: Option[bool]
    showHelp*: bool
    showVersion*: bool
    unknown*: seq[string]

const
  Version* = "0.1.0"

proc parseIntOrDefault(s: string; fallback: int): int =
  if s.len == 0:
    return fallback
  var n = 0
  if parseInt(s, n) == s.len:
    return n
  fallback

proc envInt(name: string; fallback: int): int =
  parseIntOrDefault(getEnv(name), fallback)

proc availableParallelism(): int =
  let n = countProcessors()
  if n > 0: n else: 1

proc defaultArgs*(): Args =
  Args(
    config: @[],
    option: @[],
    readOnly: false,
    maintenance: false,
    console: false,
    execute: @[],
    test: @[],
    bench: @[],
    workerThreads: envInt("TOKIO_WORKER_THREADS", availableParallelism()),
    globalEventInterval: envInt("TOKIO_GLOBAL_QUEUE_INTERVAL", 192),
    kernelEventInterval: envInt("TOKIO_EVENT_INTERVAL", 512),
    kernelEventsPerTick: envInt("TOKIO_MAX_IO_EVENTS_PER_TICK", 512),
    workerHistogramInterval: envInt("TUWUNEL_RUNTIME_HISTOGRAM_INTERVAL", 25),
    workerHistogramBuckets: envInt("TUWUNEL_RUNTIME_HISTOGRAM_BUCKETS", 20),
    workerAffinity: true,
    gcOnPark: none(bool),
    gcMuzzy: none(bool),
    showHelp: false,
    showVersion: false,
    unknown: @[],
  )

proc parseBoolLike(s: string; fallback: bool): bool =
  if s.len == 0:
    return fallback
  case s.toLowerAscii()
  of "1", "true", "yes", "on":
    true
  of "0", "false", "no", "off":
    false
  else:
    fallback

proc takeValue(argv: seq[string]; i: var int; optName: string): string =
  if i + 1 >= argv.len:
    raise newException(ValueError, "Missing value for " & optName)
  inc i
  argv[i]

proc maybeTakeOptionalValue(argv: seq[string]; i: var int): Option[string] =
  if i + 1 < argv.len and not argv[i + 1].startsWith("-"):
    inc i
    return some(argv[i])
  none(string)

proc splitLongArg(arg: string): tuple[key: string, val: string, hasVal: bool] =
  let p = arg.split("=", maxsplit = 1)
  if p.len == 2:
    (p[0], p[1], true)
  else:
    (arg, "", false)

proc parseOptionalBool(
    argv: seq[string]; i: var int; s: tuple[key: string, val: string, hasVal: bool]): Option[
    bool] =
  if s.hasVal:
    return some(parseBoolLike(s.val, true))

  let next = maybeTakeOptionalValue(argv, i)
  if next.isSome:
    return some(parseBoolLike(next.get, true))
  some(true)

proc parseArgs*(argv = commandLineParams()): Args =
  result = defaultArgs()

  var i = 0
  while i < argv.len:
    let raw = argv[i]
    let s = splitLongArg(raw)

    case s.key
    of "-h", "--help":
      result.showHelp = true
    of "-V", "--version":
      result.showVersion = true
    of "-c", "--config":
      let v = if s.hasVal: s.val else: takeValue(argv, i, s.key)
      result.config.add(v)
    of "-O", "--option":
      let v = if s.hasVal: s.val else: takeValue(argv, i, s.key)
      result.option.add(v)
    of "--read-only":
      result.readOnly = true
    of "--maintenance":
      result.maintenance = true
    of "--console":
      result.console = if s.hasVal: parseBoolLike(s.val, true) else: true
    of "--execute":
      let v = if s.hasVal: s.val else: takeValue(argv, i, s.key)
      result.execute.add(v)
    of "--test":
      if s.hasVal:
        result.test.add(s.val)
      else:
        let v = maybeTakeOptionalValue(argv, i)
        result.test.add(if v.isSome: v.get else: "")
    of "--bench":
      if s.hasVal:
        result.bench.add(s.val)
      else:
        let v = maybeTakeOptionalValue(argv, i)
        result.bench.add(if v.isSome: v.get else: "")
    of "--worker-threads":
      let v = if s.hasVal: s.val else: takeValue(argv, i, s.key)
      result.workerThreads = parseIntOrDefault(v, result.workerThreads)
    of "--global-event-interval":
      let v = if s.hasVal: s.val else: takeValue(argv, i, s.key)
      result.globalEventInterval = parseIntOrDefault(v, result.globalEventInterval)
    of "--kernel-event-interval":
      let v = if s.hasVal: s.val else: takeValue(argv, i, s.key)
      result.kernelEventInterval = parseIntOrDefault(v, result.kernelEventInterval)
    of "--kernel-events-per-tick":
      let v = if s.hasVal: s.val else: takeValue(argv, i, s.key)
      result.kernelEventsPerTick = parseIntOrDefault(v, result.kernelEventsPerTick)
    of "--worker-histogram-interval":
      let v = if s.hasVal: s.val else: takeValue(argv, i, s.key)
      result.workerHistogramInterval = parseIntOrDefault(v, result.workerHistogramInterval)
    of "--worker-histogram-buckets":
      let v = if s.hasVal: s.val else: takeValue(argv, i, s.key)
      result.workerHistogramBuckets = parseIntOrDefault(v, result.workerHistogramBuckets)
    of "--worker-affinity":
      if s.hasVal:
        result.workerAffinity = parseBoolLike(s.val, true)
      else:
        let v = maybeTakeOptionalValue(argv, i)
        result.workerAffinity = if v.isSome: parseBoolLike(v.get, true) else: true
    of "--gc-on-park":
      result.gcOnPark = parseOptionalBool(argv, i, s)
    of "--gc-muzzy":
      result.gcMuzzy = parseOptionalBool(argv, i, s)
    else:
      if raw.startsWith("-"):
        result.unknown.add(raw)
      else:
        result.execute.add(raw)

    inc i

proc usage*(): string =
  [
    "tuwunel (nim port foundation)",
    "Usage:",
    "  tuwunel [-c path]... [-O key=value] [--read-only] [--maintenance]",
    "  tuwunel --execute \"users create_user alice\"",
    "",
    "Compatibility-focused flags:",
    "  -c, --config PATH",
    "  -O, --option KEY=VALUE",
    "  --read-only",
    "  --maintenance",
    "  --execute COMMAND",
    "  --test[=NAME]",
    "  --bench[=NAME]",
  ].join("\n")

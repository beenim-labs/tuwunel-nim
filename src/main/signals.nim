import std/[os, strutils]

const
  RustPath* = "main/signals.rs"
  RustCrate* = "main"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  RuntimeSignal* = enum
    rsNone
    rsInterrupt
    rsTerminate
    rsReload

  SignalController* = ref object
    queue*: seq[RuntimeSignal]

proc initSignalController*(): SignalController =
  new(result)
  result.queue = @[]

proc parseRuntimeSignal*(raw: string): RuntimeSignal =
  let normalized = raw.strip().toLowerAscii()
  case normalized
  of "", "none":
    rsNone
  of "int", "interrupt", "sigint":
    rsInterrupt
  of "term", "terminate", "sigterm":
    rsTerminate
  of "hup", "reload", "sighup":
    rsReload
  else:
    rsNone

proc enqueueSignal*(controller: SignalController; signal: RuntimeSignal) =
  if signal == rsNone:
    return
  controller.queue.add(signal)

proc dequeueSignal*(controller: SignalController): RuntimeSignal =
  if controller.queue.len == 0:
    return rsNone
  result = controller.queue[0]
  controller.queue.delete(0)

proc hasPendingSignals*(controller: SignalController): bool =
  controller.queue.len > 0

proc loadSignalFromEnv*(
    controller: SignalController; name = "TUWUNEL_RUNTIME_SIGNAL"): RuntimeSignal =
  let signal = parseRuntimeSignal(getEnv(name))
  controller.enqueueSignal(signal)
  signal

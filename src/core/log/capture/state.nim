## Log capture state — manages the capture buffer.
##
## Ported from Rust core/log/capture/state.rs

import std/[locks]
import ./data

const
  RustPath* = "core/log/capture/state.rs"
  RustCrate* = "core"

type
  CaptureState* = ref object
    ## Thread-safe log capture state.
    lock: Lock
    capturing: bool
    logs: seq[CapturedLog]

proc newCaptureState*(): CaptureState =
  result = CaptureState(logs: @[])
  initLock(result.lock)

proc startCapture*(s: CaptureState) =
  acquire(s.lock)
  s.capturing = true
  s.logs.setLen(0)
  release(s.lock)

proc stopCapture*(s: CaptureState) =
  acquire(s.lock)
  s.capturing = false
  release(s.lock)

proc isCapturing*(s: CaptureState): bool =
  acquire(s.lock)
  result = s.capturing
  release(s.lock)

proc addLog*(s: CaptureState; log: CapturedLog) =
  acquire(s.lock)
  if s.capturing:
    s.logs.add log
  release(s.lock)

proc getLogs*(s: CaptureState): seq[CapturedLog] =
  acquire(s.lock)
  result = s.logs
  release(s.lock)

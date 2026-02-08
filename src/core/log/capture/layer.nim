## Log capture layer — intercepts log output for capture.
##
## Ported from Rust core/log/capture/layer.rs

import ./state, ./data

const
  RustPath* = "core/log/capture/layer.rs"
  RustCrate* = "core"

proc captureLogEvent*(s: CaptureState; level, message, target: string) =
  ## Capture a log event if capture is active.
  if s.isCapturing():
    s.addLog(newCapturedLog(level, message, target))

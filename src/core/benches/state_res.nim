## State resolution benchmarks.
##
## Ported from Rust core/benches/state_res.rs

import std/[times, monotimes]

const
  RustPath* = "core/benches/state_res.rs"
  RustCrate* = "core"

proc benchStateRes*(iterations: int = 1000) =
  ## Benchmark state resolution algorithm.
  let start = getMonoTime()
  for i in 0 ..< iterations:
    # Would call resolveState with test data here
    discard
  let elapsed = getMonoTime() - start
  echo "State resolution: ", iterations, " iterations in ",
       elapsed.inMilliseconds, "ms"

when isMainModule:
  benchStateRes()

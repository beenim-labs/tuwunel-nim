## Exponential backoff utilities.
##
## Ported from Rust core/utils/time/exponential_backoff.rs

import std/[times, math]

const
  RustPath* = "core/utils/time/exponential_backoff.rs"
  RustCrate* = "core"

proc continueExponentialBackoff*(
  max: Duration;
  elapsed: Duration;
  tries: uint32
): bool =
  ## Determine if the exponential backoff should continue.
  ## Returns true if the elapsed time hasn't exhausted the backoff for
  ## the given number of tries.
  let backoff = initDuration(
    seconds = int64(min(float64(max.inSeconds),
      pow(2.0, float64(tries))))
  )
  elapsed < backoff

proc continueExponentialBackoffSecs*(
  maxSecs: uint64;
  elapsedSecs: uint64;
  tries: uint32
): bool =
  ## Determine if exponential backoff should continue (seconds variant).
  let backoff = min(maxSecs, uint64(pow(2.0, float64(tries))))
  elapsedSecs < backoff

proc exponentialBackoffDuration*(tries: uint32; maxSecs: uint64 = 86400): Duration =
  ## Calculate the exponential backoff duration for a given number of tries.
  let secs = min(maxSecs, uint64(pow(2.0, float64(tries))))
  initDuration(seconds = int64(secs))

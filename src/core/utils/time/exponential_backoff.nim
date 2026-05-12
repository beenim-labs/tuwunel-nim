import core/utils/time as time_utils

const
  RustPath* = "core/utils/time/exponential_backoff.rs"
  RustCrate* = "core"

proc saturatingMul(duration: time_utils.Duration; factor: uint64): time_utils.Duration =
  if factor == 0'u64:
    return time_utils.durationFromNanos(0)
  if duration.nanos > high(uint64) div factor:
    return time_utils.durationFromNanos(high(uint64))
  time_utils.durationFromNanos(duration.nanos * factor)

proc continueExponentialBackoff*(
  minDuration: time_utils.Duration;
  maxDuration: time_utils.Duration;
  elapsed: time_utils.Duration;
  tries: uint32;
): bool =
  var threshold = minDuration.saturatingMul(uint64(tries))
  threshold = threshold.saturatingMul(uint64(tries))
  if threshold.nanos > maxDuration.nanos:
    threshold = maxDuration
  elapsed.nanos < threshold.nanos

proc continueExponentialBackoffSecs*(minSecs, maxSecs: uint64; elapsedSecs: uint64; tries: uint32): bool =
  continueExponentialBackoff(
    time_utils.durationFromSecs(minSecs),
    time_utils.durationFromSecs(maxSecs),
    time_utils.durationFromSecs(elapsedSecs),
    tries,
  )

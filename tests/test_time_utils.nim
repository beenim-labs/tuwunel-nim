import std/[strutils, unittest]

import core/utils/time as time_utils
import core/utils/time/exponential_backoff as backoff_utils

suite "time utility parity":
  test "duration parsing and pretty formatting follow Rust unit selection":
    let parsed = time_utils.parseDuration("90s")
    check parsed.ok
    check parsed.duration.asSecs() == 90'u64

    check time_utils.parseDuration("12ms").duration.asMillis() == 12'u64
    check not time_utils.parseDuration("bad").ok

    check time_utils.pretty(time_utils.durationFromSecs(90)) == "1.50 minutes"
    check time_utils.pretty(time_utils.durationFromMillis(1500)) == "1.50 seconds"
    check time_utils.pretty(time_utils.durationFromNanos(750)) == "750.0 nanoseconds"

  test "epoch conversions and formatting expose stable UTC values":
    let epoch = time_utils.timepointFromEpoch(time_utils.durationFromSecs(0))
    check epoch.ok
    check time_utils.durationSinceEpoch(epoch.timepoint).asSecs() == 0'u64
    check time_utils.timepointHasPassed(epoch.timepoint)
    check time_utils.rfc2822FromSeconds(0).contains("1970")
    check time_utils.format(epoch.timepoint, "yyyy-MM-dd") == "1970-01-01"

  test "exponential backoff squares tries and caps at max":
    check backoff_utils.continueExponentialBackoffSecs(2, 100, 7, 2)
    check not backoff_utils.continueExponentialBackoffSecs(2, 100, 8, 2)
    check backoff_utils.continueExponentialBackoffSecs(2, 10, 9, 10)
    check not backoff_utils.continueExponentialBackoffSecs(2, 10, 10, 10)

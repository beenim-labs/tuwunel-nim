import std/[json, unittest]

import core/utils/json as json_utils

suite "json utility parity":
  test "toRaw returns an independent JSON roundtrip value":
    let original = %*{"a": 1}
    let raw = json_utils.toRaw(original)
    original["a"] = %2
    check raw["a"].getInt() == 1

  test "canonical object conversion rejects non-objects and sorts keys":
    let rejected = json_utils.toCanonicalObject(%*[1, 2, 3])
    check not rejected.ok
    check rejected.message == "Value must be an object"

    let canonical = json_utils.toCanonicalObject(%*{"b": 2, "a": {"d": 4, "c": 3}})
    check canonical.ok
    check $(canonical.value) == """{"a":{"c":3,"d":4},"b":2}"""

  test "deserialize-from-str helpers parse only JSON strings":
    check json_utils.deserializeIntFromStr(%"42").value == 42
    check json_utils.deserializeUInt64FromStr(%"42").value == 42'u64
    check json_utils.deserializeBoolFromStr(%"true").value
    check not json_utils.deserializeIntFromStr(%42).ok
    check not json_utils.deserializeBoolFromStr(%"maybe").ok

const
  RustPath* = "api/client/sync/v5/extensions/e2ee.rs"
  RustCrate* = "api"

import std/[json, tables]

proc stringArray(values: openArray[string]): JsonNode =
  result = newJArray()
  for value in values:
    result.add(%value)

proc e2eePayload*(
  changed: openArray[string] = [];
  left: openArray[string] = [];
  oneTimeKeyCounts: Table[string, int] = initTable[string, int]();
  unusedFallbackKeyTypes: openArray[string] = []
): JsonNode =
  result = %*{
    "device_lists": {
      "changed": stringArray(changed),
      "left": stringArray(left)
    },
    "device_one_time_keys_count": {},
    "device_unused_fallback_key_types": stringArray(unusedFallbackKeyTypes)
  }
  for keyType, count in oneTimeKeyCounts:
    result["device_one_time_keys_count"][keyType] = %count

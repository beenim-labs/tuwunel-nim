import std/[sets, unittest]
import core/generated_config_keys
import core/generated_config_model
import core/config_values

suite "Generated config model":
  test "model exposes all inventory keys":
    let model = defaultConfigModel()
    let flat = toFlatConfig(model)
    var uniqueKeys = initHashSet[string]()
    for key in ConfigKeys:
      uniqueKeys.incl(key)

    check ConfigModelKeyCount == ConfigKeyCount
    check flat.len == uniqueKeys.len
    for key in uniqueKeys:
      check key in flat

  test "fromFlatConfig and toFlatConfig preserve set values":
    var flat = initFlatConfig()
    flat["server_name"] = newStringValue("example.com")
    flat["rocksdb_read_only"] = newBoolValue(true)

    let model = fromFlatConfig(flat)
    let roundTrip = toFlatConfig(model)

    check roundTrip["server_name"].kind == cvString
    check roundTrip["server_name"].s == "example.com"
    check roundTrip["rocksdb_read_only"].kind == cvBool
    check roundTrip["rocksdb_read_only"].b

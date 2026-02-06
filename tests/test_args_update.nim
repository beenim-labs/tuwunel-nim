import std/[strutils, unittest]
import core/config_merge
import core/config_values
import main/[args, args_update]

suite "Args update compatibility":
  test "read-only and maintenance flags mutate config values":
    var values = initFlatConfig()
    values["listening"] = newBoolValue(true)
    values["startup_netburst"] = newBoolValue(true)

    let a = parseArgs(@[
      "--read-only",
      "--maintenance",
      "--execute", "users create_user alice",
      "--test", "smoke",
      "-O", "server_name=\"example.com\"",
    ])

    let updated = applyArgsUpdate(values, a, ConfigMergeStats())
    check updated.ok

    let cfg = updated.values
    check cfg["rocksdb_read_only"].kind == cvBool
    check cfg["rocksdb_read_only"].b
    check cfg["listening"].kind == cvBool
    check not cfg["listening"].b
    check cfg["startup_netburst"].kind == cvBool
    check not cfg["startup_netburst"].b

    check cfg["admin_execute"].kind == cvArray
    check cfg["admin_execute"].items.len == 1
    check cfg["admin_execute"].items[0].s == "users create_user alice"

    check cfg["test"].kind == cvArray
    check cfg["test"].items.len == 1
    check cfg["test"].items[0].s == "smoke"

    check cfg["server_name"].kind == cvString
    check cfg["server_name"].s == "example.com"

  test "invalid option override is rejected":
    let a = parseArgs(@["-O", "novalue"])
    let updated = applyArgsUpdate(initFlatConfig(), a, ConfigMergeStats())
    check not updated.ok
    check "Missing '='" in updated.err

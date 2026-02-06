import std/[unittest, os]
import main/args
import core/config_bootstrap

template withEnv(name, value: string, body: untyped) =
  block:
    let had = existsEnv(name)
    let old = getEnv(name)
    if value.len == 0:
      delEnv(name)
    else:
      putEnv(name, value)
    try:
      body
    finally:
      if had:
        putEnv(name, old)
      else:
        delEnv(name)

suite "CLI and config bootstrap":
  test "core flags parse":
    let a = parseArgs(@[
      "-c", "a.toml",
      "--config=b.toml",
      "-O", "server_name=\"example.com\"",
      "--option", "allow_registration=true",
      "--read-only",
      "--maintenance",
      "--execute", "users create_user alice",
      "--test",
      "--bench=smoke",
    ])

    check a.config.len == 2
    check a.option.len == 2
    check a.readOnly
    check a.maintenance
    check a.execute.len == 1
    check a.test.len == 1
    check a.test[0] == ""
    check a.bench.len == 1
    check a.bench[0] == "smoke"

  test "option validation":
    let ok = validateOptionSyntax(@["k=v", "x=1"])
    check ok.ok

    let bad = validateOptionSyntax(@["noval"])
    check not bad.ok

  test "config path precedence shell":
    withEnv("CONDUIT_CONFIG", "conduit.toml"):
      withEnv("CONDUWUIT_CONFIG", "conduwuit.toml"):
        withEnv("TUWUNEL_CONFIG", "tuwunel_env.toml"):
          let a = parseArgs(@["-c", "local.toml"])
          let paths = resolveConfigPaths(a)
          check paths.len == 4
          check paths[0] == "conduit.toml"
          check paths[1] == "conduwuit.toml"
          check paths[2] == "tuwunel_env.toml"
          check paths[3] == "local.toml"

  test "default config path fallback":
    withEnv("CONDUIT_CONFIG", ""):
      withEnv("CONDUWUIT_CONFIG", ""):
        withEnv("TUWUNEL_CONFIG", ""):
          let a = parseArgs(@[])
          let paths = resolveConfigPaths(a)
          check paths.len == 1
          check paths[0] == defaultConfigPath()

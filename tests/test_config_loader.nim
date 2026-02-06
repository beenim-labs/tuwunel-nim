import std/[os, strformat, times, unittest]
import core/[config_loader, config_values]
import main/args

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

proc tempTomlPath(tag: string): string =
  let ts = now().toTime().toUnix()
  getTempDir() / fmt"tuwunel_nim_cfg_{tag}_{getCurrentProcessId()}_{ts}.toml"

suite "Config loader compatibility":
  test "loads file values and applies option overrides":
    let cfgPath = tempTomlPath("loader")
    let body =
      "server_name = \"from_file.example\"\n" &
      "listening = true\n" &
      "[global]\n" &
      "allow_registration = false\n"
    writeFile(cfgPath, body)

    withEnv("CONDUIT_CONFIG", ""):
      withEnv("CONDUWUIT_CONFIG", ""):
        withEnv("TUWUNEL_CONFIG", ""):
          let a = parseArgs(@[
            "-c", cfgPath,
            "-O", "server_name=\"override.example\"",
            "-O", "global.allow_registration=true",
          ])

          let loaded = loadConfigCompatibility(a)
          check loaded.ok
          check loaded.cfg.values["server_name"].kind == cvString
          check loaded.cfg.values["server_name"].s == "override.example"
          check loaded.cfg.values["global.allow_registration"].kind == cvBool
          check loaded.cfg.values["global.allow_registration"].b

    if fileExists(cfgPath):
      removeFile(cfgPath)

  test "applies generated defaults on empty config set":
    withEnv("CONDUIT_CONFIG", ""):
      withEnv("CONDUWUIT_CONFIG", ""):
        withEnv("TUWUNEL_CONFIG", ""):
          let a = parseArgs(@[])
          let loaded = loadConfigCompatibility(a)
          check loaded.ok
          check loaded.cfg.values["client_sync_timeout_min"].kind == cvInt
          check loaded.cfg.values["client_sync_timeout_min"].i == 5000
          check loaded.cfg.values["dns_cache_entries"].kind == cvInt
          check loaded.cfg.values["dns_cache_entries"].i == 32768
          check loaded.cfg.values["allow_encryption"].kind == cvBool
          check loaded.cfg.values["allow_encryption"].b

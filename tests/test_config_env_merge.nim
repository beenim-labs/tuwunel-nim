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

suite "Config env precedence":
  test "file and env precedence matches compatibility order":
    let aPath = tempTomlPath("a")
    let bPath = tempTomlPath("b")
    let cPath = tempTomlPath("c")
    let dPath = tempTomlPath("d")

    writeFile(aPath, "listening = false\n")
    writeFile(bPath, "listening = true\n")
    writeFile(cPath, "listening = false\n")
    writeFile(dPath, "listening = true\n")

    withEnv("CONDUIT_CONFIG", aPath):
      withEnv("CONDUWUIT_CONFIG", bPath):
        withEnv("TUWUNEL_CONFIG", cPath):
          withEnv("CONDUIT_LISTENING", "false"):
            withEnv("TUWUNEL_LISTENING", "true"):
              withEnv("CONDUIT_GLOBAL__ALLOW_REGISTRATION", "true"):
                let a = parseArgs(@[
                  "-c", dPath,
                  "-O", "listening=false",
                ])

                let loaded = loadConfigCompatibility(a)
                check loaded.ok
                check loaded.cfg.values["listening"].kind == cvBool
                check not loaded.cfg.values["listening"].b
                check loaded.cfg.values["global.allow_registration"].kind == cvBool
                check loaded.cfg.values["global.allow_registration"].b
                check loaded.cfg.stats.loadedFiles.len == 4
                check loaded.cfg.stats.envOverrides.len >= 2
                check loaded.cfg.stats.optionOverrides.len == 1

    for p in [aPath, bPath, cPath, dPath]:
      if fileExists(p):
        removeFile(p)

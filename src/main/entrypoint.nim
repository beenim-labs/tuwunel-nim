import std/[strformat, os]
import main/args
import main/rust_delegate
import core/logging
import core/config_loader
import core/config_values

proc main*(): int =
  let delegated = runRustDelegate()
  if delegated.delegated:
    info(delegated.message)
    return delegated.exitCode

  info("Rust parity delegate unavailable; using Nim compatibility runtime")
  debug("delegate_reason=" & delegated.message)

  let a = parseArgs()

  if a.showVersion:
    echo "tuwunel-nim " & Version
    return 0

  if a.showHelp:
    echo usage()
    return 0

  if a.unknown.len > 0:
    return die("Unknown flags: " & $a.unknown)

  let cfgRes = loadConfigCompatibility(a)
  if not cfgRes.ok:
    return die(cfgRes.err)

  for p in cfgRes.cfg.configPaths:
    if not fileExists(p):
      warn(fmt"Config path does not exist yet: {p}")

  info("Bootstrapped compatibility config loader for tuwunel-nim")
  info(
    fmt"config_paths={cfgRes.cfg.configPaths.len} loaded_files={cfgRes.cfg.stats.loadedFiles.len} " &
    fmt"env_overrides={cfgRes.cfg.stats.envOverrides.len} option_overrides={cfgRes.cfg.stats.optionOverrides.len}"
  )
  debug("effective_config:\n" & renderFlatConfig(cfgRes.cfg.values))
  info("Runtime/server execution is not implemented yet in this milestone")
  0

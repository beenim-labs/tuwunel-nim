import std/[options, os, sequtils]
import main/args
import main/args_update
import config_merge
import config_values
import generated_config_model
import generated_config_defaults

type
  LoadedConfig* = object
    values*: FlatConfig
    model*: ConfigModel
    stats*: ConfigMergeStats
    configPaths*: seq[string]

proc defaultConfigPath*(): string =
  "tuwunel.toml"

proc envConfigPath(envName: string): Option[string] =
  let v = getEnv(envName)
  if v.len == 0:
    return none(string)
  some(v)

proc resolveConfigPaths*(a: Args): seq[string] =
  var paths: seq[string] = @[]

  for envName in ["CONDUIT_CONFIG", "CONDUWUIT_CONFIG", "TUWUNEL_CONFIG"]:
    let v = envConfigPath(envName)
    if v.isSome:
      paths.add(v.get)

  paths.add(a.config)
  paths = paths.filterIt(it.len > 0)

  if paths.len == 0:
    paths.add(defaultConfigPath())

  paths

proc loadConfigCompatibility*(a: Args): tuple[ok: bool, err: string, cfg: LoadedConfig] =
  let paths = resolveConfigPaths(a)
  let merged = mergeConfigFiles(paths)
  if not merged.ok:
    return (false, merged.err, LoadedConfig())

  var values = defaultConfigValues()
  mergeFlatConfig(values, merged.values)
  var stats = merged.stats

  # These follow the same order as the Rust config load path.
  mergeEnvPrefix(values, "CONDUIT_", stats)
  mergeEnvPrefix(values, "CONDUWUIT_", stats)
  mergeEnvPrefix(values, "TUWUNEL_", stats)

  let updated = applyArgsUpdate(values, a, stats)
  if not updated.ok:
    return (false, updated.err, LoadedConfig())

  (
    true,
    "",
    LoadedConfig(
      values: updated.values,
      model: fromFlatConfig(updated.values),
      stats: updated.stats,
      configPaths: paths,
    ),
  )

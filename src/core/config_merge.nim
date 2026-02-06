import std/[os, strutils]
import config_values

type
  ConfigMergeStats* = object
    loadedFiles*: seq[string]
    skippedFiles*: seq[string]
    envOverrides*: seq[string]
    optionOverrides*: seq[string]

proc normalizeEnvKey(raw: string): string =
  result = raw.toLowerAscii()
  result = result.replace("__", ".")

proc mergeConfigFile*(cfg: var FlatConfig; path: string; stats: var ConfigMergeStats): tuple[
    ok: bool, err: string] =
  if not fileExists(path):
    stats.skippedFiles.add(path)
    return (true, "")

  let parsed = parseTomlDocument(readFile(path), path)
  if not parsed.ok:
    return (false, parsed.err)

  mergeFlatConfig(cfg, parsed.data)
  stats.loadedFiles.add(path)
  (true, "")

proc mergeConfigFiles*(paths: openArray[string]): tuple[
    ok: bool, err: string, values: FlatConfig, stats: ConfigMergeStats] =
  var values = initFlatConfig()
  var stats = ConfigMergeStats()

  for path in paths:
    let merged = mergeConfigFile(values, path, stats)
    if not merged.ok:
      return (false, merged.err, initFlatConfig(), ConfigMergeStats())

  (true, "", values, stats)

proc mergeEnvPrefix*(cfg: var FlatConfig; prefix: string; stats: var ConfigMergeStats) =
  for k, v in envPairs():
    if not k.startsWith(prefix):
      continue

    let suffix = k[prefix.len .. ^1]
    if suffix.len == 0:
      continue

    let key = normalizeEnvKey(suffix)
    cfg[key] = valueFromEnvLiteral(v)
    stats.envOverrides.add(prefix & suffix)


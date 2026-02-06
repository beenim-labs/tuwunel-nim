import core/config_merge
import core/config_values
import main/args

proc applyOptionOverrides(
    values: var FlatConfig; options: seq[string]; stats: var ConfigMergeStats): tuple[
    ok: bool, err: string] =
  for option in options:
    let eq = option.find('=')
    if eq < 0:
      return (false, "Missing '=' in -O/--option: \"" & option & "\"")

    let key = option[0 ..< eq]
    if key.len == 0:
      return (false, "Missing key= in -O/--option: \"" & option & "\"")

    let valueRaw = if eq + 1 <= option.high: option[eq + 1 .. ^1] else: ""
    if valueRaw.len == 0:
      return (false, "Missing =val in -O/--option: \"" & option & "\"")

    let parsed = parseTomlValue(valueRaw)
    if not parsed.ok:
      return (false, "Invalid TOML value in -O/--option: \"" & option & "\"")

    values[key] = parsed.value
    stats.optionOverrides.add(key)

  (true, "")

proc applyArgsUpdate*(
    values: FlatConfig; a: Args; stats: ConfigMergeStats): tuple[
    ok: bool, err: string, values: FlatConfig, stats: ConfigMergeStats] =
  var merged = values
  var outStats = stats

  if a.readOnly:
    merged["rocksdb_read_only"] = newBoolValue(true)

  if a.maintenance or a.readOnly:
    merged["startup_netburst"] = newBoolValue(false)
    merged["listening"] = newBoolValue(false)

  for cmd in a.execute:
    appendStringValue(merged, "admin_execute", cmd)

  for t in a.test:
    appendStringValue(merged, "test", t)

  let opts = applyOptionOverrides(merged, a.option, outStats)
  if not opts.ok:
    return (false, opts.err, initFlatConfig(), ConfigMergeStats())

  (true, "", merged, outStats)

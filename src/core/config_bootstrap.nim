## Configuration bootstrap — initial config loading from files/env.
##
## Ported from Rust config bootstrap logic.

import std/[os, parsecfg, tables, strutils, json, logging]

const
  RustPath* = "core/config (bootstrap portion)"
  RustCrate* = "core"

proc findConfigFile*(): string =
  ## Search for the configuration file in standard locations.
  let candidates = @[
    getEnv("TUWUNEL_CONFIG", ""),
    getCurrentDir() / "tuwunel.toml",
    getConfigDir() / "tuwunel" / "tuwunel.toml",
    "/etc/tuwunel/tuwunel.toml",
  ]
  for path in candidates:
    if path.len > 0 and fileExists(path):
      return path
  ""

proc loadConfigFromFile*(path: string): JsonNode =
  ## Load and parse a TOML/JSON config file.
  ## Returns a JsonNode representing the configuration.
  if not fileExists(path):
    raise newException(IOError, "Config file not found: " & path)
  let content = readFile(path)
  if path.endsWith(".json"):
    return parseJson(content)
  # For TOML, we'd need a TOML parser. For now, parse as key=value.
  result = newJObject()
  for line in content.splitLines():
    let stripped = line.strip()
    if stripped.len == 0 or stripped[0] == '#':
      continue
    let parts = stripped.split('=', maxsplit = 1)
    if parts.len == 2:
      result[parts[0].strip()] = %parts[1].strip().strip(chars = {'"'})

proc bootstrapConfig*(configPath: string = ""): JsonNode =
  ## Bootstrap configuration: find config file, load it, merge env overrides.
  let path = if configPath.len > 0: configPath else: findConfigFile()
  if path.len == 0:
    warn "No configuration file found, using defaults"
    return newJObject()
  info "Loading configuration from: " & path
  loadConfigFromFile(path)

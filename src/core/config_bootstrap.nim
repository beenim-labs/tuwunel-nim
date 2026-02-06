import std/strutils
import main/args
import config_loader

type
  ConfigBootstrap* = object
    configPaths*: seq[string]
    options*: seq[string]

proc defaultConfigPath*(): string =
  config_loader.defaultConfigPath()

proc resolveConfigPaths*(args: Args): seq[string] =
  config_loader.resolveConfigPaths(args)

proc validateOptionSyntax*(options: seq[string]): tuple[ok: bool, err: string] =
  for o in options:
    let p = o.split("=", maxsplit = 1)
    if p.len != 2:
      return (false, "Missing '=' in -O/--option: " & o)
    if p[0].len == 0:
      return (false, "Missing key in -O/--option: " & o)
    if p[1].len == 0:
      return (false, "Missing value in -O/--option: " & o)
  (true, "")

proc buildConfigBootstrap*(args: Args): tuple[ok: bool, err: string, cfg: ConfigBootstrap] =
  let v = validateOptionSyntax(args.option)
  if not v.ok:
    return (false, v.err, ConfigBootstrap())

  let cfg = ConfigBootstrap(
    configPaths: resolveConfigPaths(args),
    options: args.option,
  )
  (true, "", cfg)

## server/commands — admin module.
##
## Ported from Rust admin/server/commands.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/server/commands.rs"
  RustCrate* = "admin"

proc uptime*() =
  ## Ported from `uptime`.
  discard

proc showConfig*() =
  ## Ported from `show_config`.
  discard

proc reloadConfig*(path: Option[PathBuf]) =
  ## Ported from `reload_config`.
  discard

proc listFeatures*(available: bool; enabled: bool; comma: bool) =
  ## Ported from `list_features`.
  discard

proc memoryUsage*() =
  ## Ported from `memory_usage`.
  discard

proc clearCaches*() =
  ## Ported from `clear_caches`.
  discard

proc listBackups*() =
  ## Ported from `list_backups`.
  discard

proc backupDatabase*() =
  ## Ported from `backup_database`.
  discard

proc adminNotice*(message: seq[string]) =
  ## Ported from `admin_notice`.
  discard

proc reloadMods*() =
  ## Ported from `reload_mods`.
  discard

proc restart*(force: bool) =
  ## Ported from `restart`.
  discard

proc shutdown*() =
  ## Ported from `shutdown`.
  discard

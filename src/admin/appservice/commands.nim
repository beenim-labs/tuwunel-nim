## appservice/commands — admin module.
##
## Ported from Rust admin/appservice/commands.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/appservice/commands.rs"
  RustCrate* = "admin"

proc register*() =
  ## Ported from `register`.
  discard

proc unregister*(appserviceIdentifier: string) =
  ## Ported from `unregister`.
  discard

proc showAppserviceConfig*(appserviceIdentifier: string) =
  ## Ported from `show_appservice_config`.
  discard

proc listRegistered*() =
  ## Ported from `list_registered`.
  discard

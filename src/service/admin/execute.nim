## admin/execute — service module.
##
## Ported from Rust service/admin/execute.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/admin/execute.rs"
  RustCrate* = "service"

proc consoleAutoStart*() =
  ## Ported from `console_auto_start`.
  discard

proc consoleAutoStop*() =
  ## Ported from `console_auto_stop`.
  discard

proc startupExecute*() =
  ## Ported from `startup_execute`.
  discard

proc signalExecute*() =
  ## Ported from `signal_execute`.
  discard

proc executeCommand*(i: int; command: string) =
  ## Ported from `execute_command`.
  discard

proc executeCommandOutput*(i: int; content: RoomMessageEventContent) =
  ## Ported from `execute_command_output`.
  discard

proc executeCommandError*(i: int; content: RoomMessageEventContent) =
  ## Ported from `execute_command_error`.
  discard

proc executeCommandOutput*(i: int; content: RoomMessageEventContent) =
  ## Ported from `execute_command_output`.
  discard

proc executeCommandError*(i: int; content: RoomMessageEventContent) =
  ## Ported from `execute_command_error`.
  discard

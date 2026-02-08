## admin/console — service module.
##
## Ported from Rust service/admin/console.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/admin/console.rs"
  RustCrate* = "service"

type
  Console* = ref object
    discard

proc handleSignal*(self: Console; sig: 'static str) =
  ## Ported from `handle_signal`.
  discard

proc start*(self: Console) =
  ## Ported from `start`.
  discard

proc close*(self: Console) =
  ## Ported from `close`.
  discard

proc interrupt*(self: Console) =
  ## Ported from `interrupt`.
  discard

proc interruptReadline*(self: Console) =
  ## Ported from `interrupt_readline`.
  discard

proc interruptCommand*(self: Console) =
  ## Ported from `interrupt_command`.
  discard

proc worker*(self: Console) =
  ## Ported from `worker`.
  discard

proc readline*(self: Console): ReadlineEvent =
  ## Ported from `readline`.
  discard

proc handle*(self: Console; line: string) =
  ## Ported from `handle`.
  discard

proc process*(self: Console; line: string) =
  ## Ported from `process`.
  discard

proc outputErr*(self: Console; outputContent: RoomMessageEventContent) =
  ## Ported from `output_err`.
  discard

proc output*(self: Console; outputContent: RoomMessageEventContent) =
  ## Ported from `output`.
  discard

proc setHistory*(self: Console; readline: mut Readline) =
  ## Ported from `set_history`.
  discard

proc addHistory*(self: Console; line: string) =
  ## Ported from `add_history`.
  discard

proc tabComplete*(self: Console; line: string): string =
  ## Ported from `tab_complete`.
  ""

proc printErr*(markdown: string) =
  ## Ported from `print_err`.
  discard

proc print*(markdown: string) =
  ## Ported from `print`.
  discard

proc configureOutputErr*(output: MadSkin): MadSkin =
  ## Ported from `configure_output_err`.
  discard

proc configureOutput*(output: MadSkin): MadSkin =
  ## Ported from `configure_output`.
  discard

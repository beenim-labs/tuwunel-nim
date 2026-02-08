## admin/processor — admin module.
##
## Ported from Rust admin/processor.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/processor.rs"
  RustCrate* = "admin"

proc complete*(line: string): string =
  ## Ported from `complete`.
  ""

proc dispatch*(services: Services; command: CommandInput): ProcessorFuture =
  ## Ported from `dispatch`.
  discard

proc handleCommand*(services: Services; command: CommandInput): Processor =
  ## Ported from `handle_command`.
  discard

proc processCommand*(services: Services; input: CommandInput): Processor =
  ## Ported from `process_command`.
  discard

proc handlePanic*(error: Error; command: CommandInput): Processor =
  ## Ported from `handle_panic`.
  discard

proc process*(context: Context<'_>; command: AdminCommand; args: [string]): (, string) =
  ## Ported from `process`.
  discard

proc captureCreate*(context: Context<'_>): (Capture, Mutex<string>) =
  ## Ported from `capture_create`.
  discard

proc parseCommand*(line: string): (AdminCommand)> =
  ## Ported from `parse_command`.
  discard

proc completeCommand*(cmd: clap::Command; line: string): string =
  ## Ported from `complete_command`.
  ""

proc parseLine*(commandLine: string): seq[string] =
  ## Ported from `parse_line`.
  @[]

proc reply*(content: RoomMessageEventContent; replyId: Option[string]): RoomMessageEventContent =
  ## Ported from `reply`.
  discard

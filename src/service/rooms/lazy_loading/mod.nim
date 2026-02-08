## lazy_loading/mod — service module.
##
## Ported from Rust service/rooms/lazy_loading/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/lazy_loading/mod.rs"
  RustCrate* = "service"

type
  Status* = enum
    unseen
    seen

type
  Service* = ref object
    discard

type
  Context* = ref object
    discard

proc isEnabled*(self: Service): bool =
  ## Ported from `is_enabled`.
  false

proc includeRedundantMembers*(self: Service): bool =
  ## Ported from `include_redundant_members`.
  false

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc reset*(self: Service; ctx: Context<'_>) =
  ## Ported from `reset`.
  discard

proc witnessRetain*(self: Service; senders: Witness; ctx: Context<'_>): Witness =
  ## Ported from `witness_retain`.
  discard

proc intoStatus*(result: Handle<'_>): Status =
  ## Ported from `into_status`.
  discard

proc includeRedundantMembers*(self: Service): bool =
  ## Ported from `include_redundant_members`.
  false

proc isEnabled*(self: Service): bool =
  ## Ported from `is_enabled`.
  false

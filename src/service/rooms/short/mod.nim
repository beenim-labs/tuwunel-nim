## short/mod — service module.
##
## Ported from Rust service/rooms/short/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/short/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    discard

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc getOrCreateShorteventid*(self: Service; eventId: string): Shortstring =
  ## Ported from `get_or_create_shorteventid`.
  discard

proc createShorteventid*(self: Service; eventId: string): Shortstring =
  ## Ported from `create_shorteventid`.
  discard

proc getShorteventid*(self: Service; eventId: string): Shortstring =
  ## Ported from `get_shorteventid`.
  discard

proc getOrCreateShortstatekey*(self: Service; eventType: StateEventType; stateKey: string): ShortStateKey =
  ## Ported from `get_or_create_shortstatekey`.
  discard

proc getShortstatekey*(self: Service; eventType: StateEventType; stateKey: string): ShortStateKey =
  ## Ported from `get_shortstatekey`.
  discard

proc getStatekeyFromShort*(self: Service; shortstatekey: ShortStateKey): (StateEventType =
  ## Ported from `get_statekey_from_short`.
  discard

proc getOrCreateShortstatehash*(self: Service; stateHash: [u8]): (ShortStateHash, bool) =
  ## Ported from `get_or_create_shortstatehash`.
  discard

proc getShortroomid*(self: Service; roomId: string): Shortstring =
  ## Ported from `get_shortroomid`.
  discard

proc getRoomidFromShort*(self: Service; shortroomid: Shortstring): string =
  ## Ported from `get_roomid_from_short`.
  ""

proc getOrCreateShortroomid*(self: Service; roomId: string): Shortstring =
  ## Ported from `get_or_create_shortroomid`.
  discard

proc deleteShortroomid*(self: Service; roomId: string) =
  ## Ported from `delete_shortroomid`.
  discard

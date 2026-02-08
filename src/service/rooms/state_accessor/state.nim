## state_accessor/state — service module.
##
## Ported from Rust service/rooms/state_accessor/state.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/state_accessor/state.rs"
  RustCrate* = "service"

proc userWasJoined*(shortstatehash: ShortStateHash; userId: string): bool =
  ## Ported from `user_was_joined`.
  false

proc userWasInvited*(shortstatehash: ShortStateHash; userId: string): bool =
  ## Ported from `user_was_invited`.
  false

proc userMembership*(shortstatehash: ShortStateHash; userId: string): MembershipState =
  ## Ported from `user_membership`.
  discard

proc stateContains*(shortstatehash: ShortStateHash; eventType: StateEventType; stateKey: string): bool =
  ## Ported from `state_contains`.
  false

proc stateContainsType*(shortstatehash: ShortStateHash; eventType: StateEventType): bool =
  ## Ported from `state_contains_type`.
  false

proc stateContainsShortstatekey*(shortstatehash: ShortStateHash; shortstatekey: ShortStateKey): bool =
  ## Ported from `state_contains_shortstatekey`.
  false

proc stateGet*(shortstatehash: ShortStateHash; eventType: StateEventType; stateKey: string): Pdu =
  ## Ported from `state_get`.
  discard

proc stateGetId*(shortstatehash: ShortStateHash; eventType: StateEventType; stateKey: string): string =
  ## Ported from `state_get_id`.
  ""

proc stateGetShortid*(shortstatehash: ShortStateHash; eventType: StateEventType; stateKey: string): Shortstring =
  ## Ported from `state_get_shortid`.
  discard

proc stateRemoved*(shortstatehash: pair_of!(ShortStateHash) =
  ## Ported from `state_removed`.
  discard

proc stateAdded*(shortstatehash: pair_of!(ShortStateHash) =
  ## Ported from `state_added`.
  discard

proc stateFull*(shortstatehash: ShortStateHash): impl Stream<Item = ((StateEventType, StateKey), impl Event)> + Send + '_ =
  ## Ported from `state_full`.
  discard

proc stateFullPdus*(shortstatehash: ShortStateHash): impl Stream<Item = impl Event> + Send + '_ =
  ## Ported from `state_full_pdus`.
  discard

proc stateFullIds*(shortstatehash: ShortStateHash): impl Stream<Item = (ShortStateKey, string)> + Send + '_ =
  ## Ported from `state_full_ids`.
  discard

proc stateFullShortids*(shortstatehash: ShortStateHash): impl Stream<Item = (ShortStateKey> + Send + '_ =
  ## Ported from `state_full_shortids`.
  discard

proc loadFullState*(shortstatehash: ShortStateHash): CompressedState =
  ## Ported from `load_full_state`.
  discard

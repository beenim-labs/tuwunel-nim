## sync/v3 — api module.
##
## Ported from Rust api/client/sync/v3.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/sync/v3.rs"
  RustCrate* = "api"

proc syncEventsRoute*() =
  ## Ported from `sync_events_route`.
  discard

proc buildEmptyResponse*(services: Services; senderUser: string; senderDevice: Option[DeviceId]; nextBatch: uint64): sync_events::v3::Response =
  ## Ported from `build_empty_response`.
  discard

proc buildSyncEvents*(services: Services; senderUser: string; senderDevice: Option[DeviceId]; since: uint64; nextBatch: uint64; fullState: bool; filter: FilterDefinition): sync_events::v3::Response =
  ## Ported from `build_sync_events`.
  discard

proc processPresenceUpdates*(services: Services; since: uint64; nextBatch: uint64; syncingUser: string; filter: FilterDefinition): PresenceUpdates =
  ## Ported from `process_presence_updates`.
  discard

proc handleLeftRoom*(services: Services; since: uint64; roomId: string; senderUser: string; nextBatch: uint64; fullState: bool; filter: FilterDefinition): Option[LeftRoom] =
  ## Ported from `handle_left_room`.
  none(LeftRoom)

proc loadLeftRoom*(services: Services; senderUser: string; roomId: string; since: uint64; leftCount: uint64; fullState: bool; filter: FilterDefinition): Option[LeftRoom] =
  ## Ported from `load_left_room`.
  none(LeftRoom)

proc loadJoinedRoom*(services: Services; senderUser: string; senderDevice: Option[DeviceId]; roomId: string; since: uint64; nextBatch: uint64; fullState: bool; filter: FilterDefinition): (JoinedRoom, HashSet<string>)> =
  ## Ported from `load_joined_room`.
  discard

proc lazyFilter*(services: Services; senderUser: string; witness: Option[Witness]; shortstatekey: ShortStateKey; shorteventid: Shortstring): Option[Shortstring] =
  ## Ported from `lazy_filter`.
  none(Shortstring)

proc calculateCounts*(services: Services; roomId: string; senderUser: string): (Option[uint64], Option[uint64], Option[seq[string]]) =
  ## Ported from `calculate_counts`.
  discard

proc calculateHeroes*(services: Services; roomId: string; senderUser: string): seq[string] =
  ## Ported from `calculate_heroes`.
  @[]

proc typingsEventForUser*(services: Services; roomId: string; senderUser: string): SyncEphemeralRoomEvent<TypingEventContent> =
  ## Ported from `typings_event_for_user`.
  discard

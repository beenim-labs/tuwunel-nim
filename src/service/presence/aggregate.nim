## presence/aggregate — service module.
##
## Ported from Rust service/presence/aggregate.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/presence/aggregate.rs"
  RustCrate* = "service"

proc clear*() =
  ## Ported from `clear`.
  discard

proc update*(userId: string; deviceKey: DeviceKey; state: PresenceState; currentlyActive: Option[bool]; lastActiveAgo: Option[UInt]; statusMsg: Option[string]; nowMs: uint64) =
  ## Ported from `update`.
  discard

proc aggregate*(userId: string; nowMs: uint64; idleTimeoutMs: uint64; offlineTimeoutMs: uint64): AggregatedPresence =
  ## Ported from `aggregate`.
  discard

proc effectiveDeviceState*(state: PresenceState; lastActiveAge: uint64; idleTimeoutMs: uint64; offlineTimeoutMs: uint64): PresenceState =
  ## Ported from `effective_device_state`.
  discard

proc stateRank*(state: PresenceState): u8 =
  ## Ported from `state_rank`.
  discard

proc aggregatesRankAndStatusMsg*() =
  ## Ported from `aggregates_rank_and_status_msg`.
  discard

proc degradesOnlineToUnavailableAfterIdle*() =
  ## Ported from `degrades_online_to_unavailable_after_idle`.
  discard

proc dropsStaleDevicesOnAggregate*() =
  ## Ported from `drops_stale_devices_on_aggregate`.
  discard

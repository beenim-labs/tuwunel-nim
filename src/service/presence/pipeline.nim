## presence/pipeline — service module.
##
## Ported from Rust service/presence/pipeline.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/presence/pipeline.rs"
  RustCrate* = "service"

proc deviceKey*(deviceId: Option[DeviceId]; isRemote: bool): aggregate::DeviceKey =
  ## Ported from `device_key`.
  discard

proc schedulePresenceTimer*(userId: string; presenceState: PresenceState; count: uint64) =
  ## Ported from `schedule_presence_timer`.
  discard

proc refreshSkipDecision*(refreshWindowMs: Option[uint64]; lastEvent: Option[PresenceEvent]; lastCount: Option[uint64]): Option[(uint64, uint64)] =
  ## Ported from `refresh_skip_decision`.
  none((uint64, uint64))

proc timerIsStale*(expectedCount: uint64; currentCount: uint64): bool =
  ## Ported from `timer_is_stale`.
  false

proc applyDevicePresenceUpdate*(userId: string; deviceKey: aggregate::DeviceKey; state: PresenceState; currentlyActive: Option[bool]; lastActiveAgo: Option[UInt]; statusMsg: Option[string]; refreshWindowMs: Option[uint64]) =
  ## Ported from `apply_device_presence_update`.
  discard

proc maybePingPresence*(userId: string; deviceId: Option[DeviceId]; newState: PresenceState) =
  ## Ported from `maybe_ping_presence`.
  discard

proc setPresenceForDevice*(userId: string; deviceId: Option[DeviceId]; state: PresenceState; statusMsg: Option[string]) =
  ## Ported from `set_presence_for_device`.
  discard

proc setPresenceFromFederation*(userId: string; state: PresenceState; currentlyActive: bool; lastActiveAgo: UInt; statusMsg: Option[string]) =
  ## Ported from `set_presence_from_federation`.
  discard

proc setPresence*(userId: string; state: PresenceState; currentlyActive: Option[bool]; lastActiveAgo: Option[UInt]; statusMsg: Option[string]) =
  ## Ported from `set_presence`.
  discard

proc processPresenceTimer*(userId: string; expectedCount: uint64) =
  ## Ported from `process_presence_timer`.
  discard

proc presenceTimer*(userId: string; timeout: Duration; count: uint64): TimerFired =
  ## Ported from `presence_timer`.
  discard

proc refreshWindowSkipDecision*() =
  ## Ported from `refresh_window_skip_decision`.
  discard

proc timerStaleDetection*() =
  ## Ported from `timer_stale_detection`.
  discard

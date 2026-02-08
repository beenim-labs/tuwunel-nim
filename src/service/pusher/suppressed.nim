## pusher/suppressed — service module.
##
## Ported from Rust service/pusher/suppressed.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/pusher/suppressed.rs"
  RustCrate* = "service"

proc lock*(): std::sync::MutexGuard<'_, HashMap<string, HashMap<string, PushkeyQueue>>> =
  ## Ported from `lock`.
  discard

proc drainRoom*(queue: VecDeque<SuppressedEvent>): seq[RawPduId] =
  ## Ported from `drain_room`.
  @[]

proc dropOneFront*(queue: mut VecDeque<SuppressedEvent>; totalEvents: mut int): bool =
  ## Ported from `drop_one_front`.
  false

proc queueSuppressedPush*(userId: string; pushkey: string; roomId: string; pduId: RawPduId): bool =
  ## Ported from `queue_suppressed_push`.
  false

proc takeSuppressedForPushkey*(userId: string; pushkey: string): seq[(string, Vec<RawPduId])> =
  ## Ported from `take_suppressed_for_pushkey`.
  @[]

proc takeSuppressedForUser*(userId: string): SuppressedPushes =
  ## Ported from `take_suppressed_for_user`.
  discard

proc clearSuppressedRoom*(userId: string; roomId: string): int =
  ## Ported from `clear_suppressed_room`.
  0

proc clearSuppressedPushkey*(userId: string; pushkey: string): int =
  ## Ported from `clear_suppressed_pushkey`.
  0

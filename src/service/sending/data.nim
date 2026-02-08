## sending/data — service module.
##
## Ported from Rust service/sending/data.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/sending/data.rs"
  RustCrate* = "service"

type
  Data* = ref object
    discard

proc deleteActiveRequest*(self: Data; key: [u8]) =
  ## Ported from `delete_active_request`.
  discard

proc deleteAllActiveRequestsFor*(self: Data; destination: Destination) =
  ## Ported from `delete_all_active_requests_for`.
  discard

proc deleteAllRequestsFor*(self: Data; destination: Destination) =
  ## Ported from `delete_all_requests_for`.
  discard

proc activeRequests*(self: Data): impl Stream<Item = OutgoingItem> + Send + '_ =
  ## Ported from `active_requests`.
  discard

proc activeRequestsFor*(self: Data; destination: Destination): impl Stream<Item = SendingItem> + Send + '_ + use<'_> =
  ## Ported from `active_requests_for`.
  discard

proc queuedRequests*(self: Data; destination: Destination): impl Stream<Item = QueueItem> + Send + '_ + use<'_> =
  ## Ported from `queued_requests`.
  discard

proc setLatestEducount*(self: Data; serverName: string; lastCount: uint64) =
  ## Ported from `set_latest_educount`.
  discard

proc getLatestEducount*(self: Data; serverName: string): uint64 =
  ## Ported from `get_latest_educount`.
  0

proc parseServercurrentevent*(key: [u8]; value: [u8]): (Destination =
  ## Ported from `parse_servercurrentevent`.
  discard

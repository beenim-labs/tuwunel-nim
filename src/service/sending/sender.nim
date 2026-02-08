## sending/sender — service module.
##
## Ported from Rust service/sending/sender.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/sending/sender.rs"
  RustCrate* = "service"

proc sender*(id: int) =
  ## Ported from `sender`.
  discard

proc handleResponseErr*(dest: Destination; statuses: mut CurTransactionStatus; e: Error) =
  ## Ported from `handle_response_err`.
  discard

proc selectEvents*(dest: Destination; newEvents: seq[QueueItem]; send: event and full key
		statuses: mut CurTransactionStatus): Option[seq[SendingEvent]] =
  ## Ported from `select_events`.
  none(seq[SendingEvent])

proc selectEventsCurrent*(dest: Destination; statuses: mut CurTransactionStatus): (bool =
  ## Ported from `select_events_current`.
  discard

proc selectEdus*(serverName: string): (EduVec =
  ## Ported from `select_edus`.
  discard

proc selectEdusDeviceChanges*(serverName: string; since: (uint64) =
  ## Ported from `select_edus_device_changes`.
  discard

proc selectEdusReceipts*(serverName: string; since: (uint64) =
  ## Ported from `select_edus_receipts`.
  discard

proc selectEdusReceiptsRoom*(roomId: string; since: (uint64) =
  ## Ported from `select_edus_receipts_room`.
  discard

proc selectEdusPresence*(serverName: string; since: (uint64) =
  ## Ported from `select_edus_presence`.
  discard

proc sendEvents*(dest: Destination; events: seq[SendingEvent]): SendingFuture<'_> =
  ## Ported from `send_events`.
  discard

proc sendEventsDestAppservice*(id: string; events: seq[SendingEvent]): Sending =
  ## Ported from `send_events_dest_appservice`.
  discard

proc sendEventsDestPush*(userId: string; pushkey: string; events: seq[SendingEvent]): Sending =
  ## Ported from `send_events_dest_push`.
  discard

proc scheduleFlushSuppressedForPushkey*(userId: string; pushkey: string; reason: 'static str) =
  ## Ported from `schedule_flush_suppressed_for_pushkey`.
  discard

proc scheduleFlushSuppressedForUser*(userId: string; reason: 'static str) =
  ## Ported from `schedule_flush_suppressed_for_user`.
  discard

proc enqueueSuppressedPushEvents*(userId: string; pushkey: string; events: [SendingEvent]): int =
  ## Ported from `enqueue_suppressed_push_events`.
  0

proc flushSuppressedRooms*(userId: string; pushkey: string; pusher: ruma::api::client::push::Pusher; rulesForUser: push::Ruleset; rooms: Vec<(string) =
  ## Ported from `flush_suppressed_rooms`.
  discard

proc flushSuppressedForPushkey*(userId: string; pushkey: string; reason: 'static str) =
  ## Ported from `flush_suppressed_for_pushkey`.
  discard

proc flushSuppressedForUser*(userId: string; reason: 'static str) =
  ## Ported from `flush_suppressed_for_user`.
  discard

proc pushingSuppressed*(userId: string): bool =
  ## Ported from `pushing_suppressed`.
  false

proc sendEventsDestFederation*(server: string; events: seq[SendingEvent]): Sending =
  ## Ported from `send_events_dest_federation`.
  discard

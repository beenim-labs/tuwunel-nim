## pusher/notification — service module.
##
## Ported from Rust service/pusher/notification.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/pusher/notification.rs"
  RustCrate* = "service"

proc resetNotificationCounts*(userId: string; roomId: string) =
  ## Ported from `reset_notification_counts`.
  discard

proc notificationCount*(userId: string; roomId: string): uint64 =
  ## Ported from `notification_count`.
  0

proc highlightCount*(userId: string; roomId: string): uint64 =
  ## Ported from `highlight_count`.
  0

proc lastNotificationRead*(userId: string; roomId: string): uint64 =
  ## Ported from `last_notification_read`.
  0

proc deleteRoomNotificationRead*(roomId: string) =
  ## Ported from `delete_room_notification_read`.
  discard

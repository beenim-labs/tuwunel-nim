## pusher/append — service module.
##
## Ported from Rust service/pusher/append.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/pusher/append.rs"
  RustCrate* = "service"

type
  Notified* = ref object
    ts*: uint64
    sroomid*: Shortstring
    tag*: Option[ProfileTag]
    actions*: Actions

proc appendPdu*(self: Notified; pduId: RawPduId; pdu: Pdu) =
  ## Ported from `append_pdu`.
  discard

proc incrementNotificationcount*(self: Notified; roomId: string; userId: string) =
  ## Ported from `increment_notificationcount`.
  discard

proc incrementHighlightcount*(self: Notified; roomId: string; userId: string) =
  ## Ported from `increment_highlightcount`.
  discard

proc increment*(db: Map; key: (string) =
  ## Ported from `increment`.
  discard

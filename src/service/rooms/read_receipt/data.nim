## read_receipt/data — service module.
##
## Ported from Rust service/rooms/read_receipt/data.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/read_receipt/data.rs"
  RustCrate* = "service"

proc readreceiptUpdate*(userId: string; roomId: string; event: ReceiptEvent) =
  ## Ported from `readreceipt_update`.
  discard

proc privateReadSet*(roomId: string; userId: string; pduCount: uint64) =
  ## Ported from `private_read_set`.
  discard

proc privateReadGetCount*(roomId: string; userId: string): uint64 =
  ## Ported from `private_read_get_count`.
  0

proc lastPrivatereadUpdate*(userId: string; roomId: string): uint64 =
  ## Ported from `last_privateread_update`.
  0

proc deleteAllReadReceipts*(roomId: string) =
  ## Ported from `delete_all_read_receipts`.
  discard

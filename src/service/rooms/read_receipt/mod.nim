## read_receipt/mod — service module.
##
## Ported from Rust service/rooms/read_receipt/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/read_receipt/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    discard

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc readreceiptUpdate*(self: Service; userId: string; roomId: string; event: ReceiptEvent) =
  ## Ported from `readreceipt_update`.
  discard

proc privateReadGet*(self: Service; roomId: string; userId: string): Raw<AnySyncEphemeralRoomEvent> =
  ## Ported from `private_read_get`.
  discard

proc privateReadSet*(self: Service; roomId: string; userId: string; count: uint64) =
  ## Ported from `private_read_set`.
  discard

proc privateReadGetCount*(self: Service; roomId: string; userId: string): uint64 =
  ## Ported from `private_read_get_count`.
  0

proc lastPrivatereadUpdate*(self: Service; userId: string; roomId: string): uint64 =
  ## Ported from `last_privateread_update`.
  0

proc lastReceiptCount*(self: Service; roomId: string; userId: Option[string]; since: Option[uint64]): uint64 =
  ## Ported from `last_receipt_count`.
  0

proc deleteAllReadReceipts*(self: Service; roomId: string) =
  ## Ported from `delete_all_read_receipts`.
  discard

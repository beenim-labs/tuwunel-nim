## transaction_ids/mod — service module.
##
## Ported from Rust service/transaction_ids/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/transaction_ids/mod.rs"
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

proc addTxnid*(self: Service; userId: string; deviceId: Option[DeviceId]; txnId: TransactionId; data: [u8]) =
  ## Ported from `add_txnid`.
  discard

proc existingTxnid*(self: Service; userId: string; deviceId: Option[DeviceId]; txnId: TransactionId): Handle<'_> =
  ## Ported from `existing_txnid`.
  discard

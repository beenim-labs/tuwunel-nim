## extensions/receipts — api module.
##
## Ported from Rust api/client/sync/v5/extensions/receipts.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/sync/v5/extensions/receipts.rs"
  RustCrate* = "api"

proc collect*(syncInfo: SyncInfo<'_>; conn: Connection; window: Window): response::Receipts =
  ## Ported from `collect`.
  discard

proc collectRoom*(conn: Connection; Window: Window; roomId: string): Option[(string, Raw<SyncReceiptEvent])> =
  ## Ported from `collect_room`.
  none((string, Raw<SyncReceiptEvent]))

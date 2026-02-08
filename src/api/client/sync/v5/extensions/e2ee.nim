## extensions/e2ee — api module.
##
## Ported from Rust api/client/sync/v5/extensions/e2ee.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/sync/v5/extensions/e2ee.rs"
  RustCrate* = "api"

proc collect*(syncInfo: SyncInfo<'_>; conn: Connection): response::E2EE =
  ## Ported from `collect`.
  discard

proc collectRoom*(conn: Connection; roomId: string): pair_of!(HashSet<string)> =
  ## Ported from `collect_room`.
  discard

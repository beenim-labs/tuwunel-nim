## media/migrations — service module.
##
## Ported from Rust service/media/migrations.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/media/migrations.rs"
  RustCrate* = "service"

proc migrateSha256Media*(services: Services) =
  ## Ported from `migrate_sha256_media`.
  discard

proc checkupSha256Media*(services: Services) =
  ## Ported from `checkup_sha256_media`.
  discard

proc handleMediaCheck*(dbs: (tuwunel_database::Map; tuwunelDatabase: :Map>) =
  ## Ported from `handle_media_check`.
  discard

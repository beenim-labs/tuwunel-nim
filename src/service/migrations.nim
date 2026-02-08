## service/migrations — service module.
##
## Ported from Rust service/migrations.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/migrations.rs"
  RustCrate* = "service"

proc migrations*(services: Services) =
  ## Ported from `migrations`.
  discard

proc fresh*(services: Services) =
  ## Ported from `fresh`.
  discard

proc migrate*(services: Services) =
  ## Ported from `migrate`.
  discard

proc dbLt12*(services: Services) =
  ## Ported from `db_lt_12`.
  discard

proc dbLt13*(services: Services) =
  ## Ported from `db_lt_13`.
  discard

proc fixBadDoubleSeparatorInStateCache*(services: Services) =
  ## Ported from `fix_bad_double_separator_in_state_cache`.
  discard

proc retroactivelyFixBadDataFromRoomuseridJoined*(services: Services) =
  ## Ported from `retroactively_fix_bad_data_from_roomuserid_joined`.
  discard

proc fixReferencedeventsMissingSep*(services: Services) =
  ## Ported from `fix_referencedevents_missing_sep`.
  discard

proc fixReadreceiptidReadreceiptDuplicates*(services: Services) =
  ## Ported from `fix_readreceiptid_readreceipt_duplicates`.
  discard

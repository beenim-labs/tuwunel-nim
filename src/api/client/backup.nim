## client/backup — api module.
##
## Ported from Rust api/client/backup.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/backup.rs"
  RustCrate* = "api"

proc createBackupVersionRoute*() =
  ## Ported from `create_backup_version_route`.
  discard

proc updateBackupVersionRoute*() =
  ## Ported from `update_backup_version_route`.
  discard

proc getLatestBackupInfoRoute*() =
  ## Ported from `get_latest_backup_info_route`.
  discard

proc getBackupInfoRoute*() =
  ## Ported from `get_backup_info_route`.
  discard

proc deleteBackupVersionRoute*() =
  ## Ported from `delete_backup_version_route`.
  discard

proc addBackupKeysRoute*() =
  ## Ported from `add_backup_keys_route`.
  discard

proc addBackupKeysForRoomRoute*() =
  ## Ported from `add_backup_keys_for_room_route`.
  discard

proc addBackupKeysForSessionRoute*() =
  ## Ported from `add_backup_keys_for_session_route`.
  discard

proc getBackupKeysRoute*() =
  ## Ported from `get_backup_keys_route`.
  discard

proc getBackupKeysForRoomRoute*() =
  ## Ported from `get_backup_keys_for_room_route`.
  discard

proc getBackupKeysForSessionRoute*() =
  ## Ported from `get_backup_keys_for_session_route`.
  discard

proc deleteBackupKeysRoute*() =
  ## Ported from `delete_backup_keys_route`.
  discard

proc deleteBackupKeysForRoomRoute*() =
  ## Ported from `delete_backup_keys_for_room_route`.
  discard

proc deleteBackupKeysForSessionRoute*() =
  ## Ported from `delete_backup_keys_for_session_route`.
  discard

proc getCountEtag*(services: Services; senderUser: string; version: string): (UInt =
  ## Ported from `get_count_etag`.
  discard

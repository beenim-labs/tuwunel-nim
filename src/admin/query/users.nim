## query/users — admin module.
##
## Ported from Rust admin/query/users.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/query/users.rs"
  RustCrate* = "admin"

proc authLdap*(userDn: string; password: string) =
  ## Ported from `auth_ldap`.
  discard

proc searchLdap*(userId: string) =
  ## Ported from `search_ldap`.
  discard

proc getSharedRooms*(userA: string; userB: string) =
  ## Ported from `get_shared_rooms`.
  discard

proc getBackupSession*(userId: string; version: string; roomId: string; sessionId: string) =
  ## Ported from `get_backup_session`.
  discard

proc getRoomBackups*(userId: string; version: string; roomId: string) =
  ## Ported from `get_room_backups`.
  discard

proc getAllBackups*(userId: string; version: string) =
  ## Ported from `get_all_backups`.
  discard

proc getBackupAlgorithm*(userId: string; version: string) =
  ## Ported from `get_backup_algorithm`.
  discard

proc getLatestBackupVersion*(userId: string) =
  ## Ported from `get_latest_backup_version`.
  discard

proc getLatestBackup*(userId: string) =
  ## Ported from `get_latest_backup`.
  discard

proc iterUsers*() =
  ## Ported from `iter_users`.
  discard

proc iterUsers2*() =
  ## Ported from `iter_users2`.
  discard

proc countUsers*() =
  ## Ported from `count_users`.
  discard

proc passwordHash*(userId: string) =
  ## Ported from `password_hash`.
  discard

proc listDevices*(userId: string) =
  ## Ported from `list_devices`.
  discard

proc listDevicesMetadata*(userId: string) =
  ## Ported from `list_devices_metadata`.
  discard

proc getDeviceMetadata*(userId: string; deviceId: OwnedDeviceId) =
  ## Ported from `get_device_metadata`.
  discard

proc getDevicesVersion*(userId: string) =
  ## Ported from `get_devices_version`.
  discard

proc countOneTimeKeys*(userId: string; deviceId: OwnedDeviceId) =
  ## Ported from `count_one_time_keys`.
  discard

proc getDeviceKeys*(userId: string; deviceId: OwnedDeviceId) =
  ## Ported from `get_device_keys`.
  discard

proc getUserSigningKey*(userId: string) =
  ## Ported from `get_user_signing_key`.
  discard

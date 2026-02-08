## users/profile — service module.
##
## Ported from Rust service/users/profile.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/users/profile.rs"
  RustCrate* = "service"

proc updateDisplayname*(userId: string; displayname: Option[string]; rooms: [string]) =
  ## Ported from `update_displayname`.
  discard

proc setDisplayname*(userId: string; displayname: Option[string]) =
  ## Ported from `set_displayname`.
  discard

proc displayname*(userId: string): string =
  ## Ported from `displayname`.
  ""

proc updateAvatarUrl*(userId: string; avatarUrl: Option[string]; blurhash: Option[string]; rooms: [string]) =
  ## Ported from `update_avatar_url`.
  discard

proc setAvatarUrl*(userId: string; avatarUrl: Option[string]) =
  ## Ported from `set_avatar_url`.
  discard

proc avatarUrl*(userId: string): string =
  ## Ported from `avatar_url`.
  ""

proc setBlurhash*(userId: string; blurhash: Option[string]) =
  ## Ported from `set_blurhash`.
  discard

proc blurhash*(userId: string): string =
  ## Ported from `blurhash`.
  ""

proc setTimezone*(userId: string; timezone: Option[string]) =
  ## Ported from `set_timezone`.
  discard

proc timezone*(userId: string): string =
  ## Ported from `timezone`.
  ""

proc setProfileKey*(userId: string; profileKey: string; profileKeyValue: Option[serde_json::Value]) =
  ## Ported from `set_profile_key`.
  discard

proc profileKey*(userId: string; profileKey: string): serde_json::Value =
  ## Ported from `profile_key`.
  discard

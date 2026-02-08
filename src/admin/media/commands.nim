## media/commands — admin module.
##
## Ported from Rust admin/media/commands.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/media/commands.rs"
  RustCrate* = "admin"

proc delete*(mxc: Option[string]; eventId: Option[string]) =
  ## Ported from `delete`.
  discard

proc deleteList*() =
  ## Ported from `delete_list`.
  discard

proc deletePastRemoteMedia*(duration: string; before: bool; after: bool; yesIWantToDeleteLocalMedia: bool) =
  ## Ported from `delete_past_remote_media`.
  discard

proc deleteAllFromUser*(username: string) =
  ## Ported from `delete_all_from_user`.
  discard

proc deleteAllFromServer*(serverName: string; yesIWantToDeleteLocalMedia: bool) =
  ## Ported from `delete_all_from_server`.
  discard

proc getFileInfo*(mxc: string) =
  ## Ported from `get_file_info`.
  discard

proc getRemoteFile*(mxc: string; server: Option[string]; timeout: uint32) =
  ## Ported from `get_remote_file`.
  discard

proc getRemoteThumbnail*(mxc: string; server: Option[string]; timeout: uint32; width: uint32; height: uint32) =
  ## Ported from `get_remote_thumbnail`.
  discard

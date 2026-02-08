## media/mod — service module.
##
## Ported from Rust service/media/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/media/mod.rs"
  RustCrate* = "service"

type
  FileMeta* = ref object
    content*: Option[seq[u8]]
    contentType*: Option[string]
    contentDisposition*: Option[ContentDisposition]

type
  Service* = ref object

# import ./blurhash

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc worker*(self: FileMeta) =
  ## Ported from `worker`.
  discard

proc name*(self: FileMeta): string =
  ## Ported from `name`.
  ""

proc create*(self: FileMeta; mxc: Mxc<'_>; user: Option[string]; contentDisposition: Option[ContentDisposition]; contentType: Option[string]; file: [u8]) =
  ## Ported from `create`.
  discard

proc delete*(self: FileMeta; mxc: Mxc<'_>) =
  ## Ported from `delete`.
  discard

proc deleteFromUser*(self: FileMeta; user: string): int =
  ## Ported from `delete_from_user`.
  0

proc get*(self: FileMeta; mxc: Mxc<'_>): Option[FileMeta] =
  ## Ported from `get`.
  none(FileMeta)

proc getAllMxcs*(self: FileMeta): seq[string] =
  ## Ported from `get_all_mxcs`.
  @[]

proc deleteAllRemoteMediaAtAfterTime*(self: FileMeta; time: SystemTime; before: bool; after: bool; yesIWantToDeleteLocalMedia: bool): int =
  ## Ported from `delete_all_remote_media_at_after_time`.
  0

proc createMediaDir*(self: FileMeta) =
  ## Ported from `create_media_dir`.
  discard

proc removeMediaFile*(self: FileMeta; key: [u8]) =
  ## Ported from `remove_media_file`.
  discard

proc createMediaFile*(self: FileMeta; key: [u8]): fs::File =
  ## Ported from `create_media_file`.
  discard

proc getMetadata*(self: FileMeta; mxc: Mxc<'_>): Option[FileMeta] =
  ## Ported from `get_metadata`.
  none(FileMeta)

proc getMediaFile*(self: FileMeta; key: [u8]): PathBuf =
  ## Ported from `get_media_file`.
  discard

proc getMediaFileSha256*(self: FileMeta; key: [u8]): PathBuf =
  ## Ported from `get_media_file_sha256`.
  discard

proc getMediaFileB64*(self: FileMeta; key: [u8]): PathBuf =
  ## Ported from `get_media_file_b64`.
  discard

proc getMediaDir*(self: FileMeta): PathBuf =
  ## Ported from `get_media_dir`.
  discard

proc encodeKey*(key: [u8]): string =
  ## Ported from `encode_key`.
  ""

## media/remote — service module.
##
## Ported from Rust service/media/remote.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/media/remote.rs"
  RustCrate* = "service"

proc fetchRemoteThumbnail*(mxc: Mxc<'_>; user: Option[string]; server: Option[string]; timeoutMs: Duration; dim: Dim): FileMeta =
  ## Ported from `fetch_remote_thumbnail`.
  discard

proc fetchRemoteContent*(mxc: Mxc<'_>; user: Option[string]; server: Option[string]; timeoutMs: Duration): FileMeta =
  ## Ported from `fetch_remote_content`.
  discard

proc fetchThumbnailAuthenticated*(mxc: Mxc<'_>; user: Option[string]; server: Option[string]; timeoutMs: Duration; dim: Dim): FileMeta =
  ## Ported from `fetch_thumbnail_authenticated`.
  discard

proc fetchContentAuthenticated*(mxc: Mxc<'_>; user: Option[string]; server: Option[string]; timeoutMs: Duration): FileMeta =
  ## Ported from `fetch_content_authenticated`.
  discard

proc fetchThumbnailUnauthenticated*(mxc: Mxc<'_>; user: Option[string]; server: Option[string]; timeoutMs: Duration; dim: Dim): FileMeta =
  ## Ported from `fetch_thumbnail_unauthenticated`.
  discard

proc fetchContentUnauthenticated*(mxc: Mxc<'_>; user: Option[string]; server: Option[string]; timeoutMs: Duration): FileMeta =
  ## Ported from `fetch_content_unauthenticated`.
  discard

proc handleThumbnailFile*(mxc: Mxc<'_>; user: Option[string]; dim: Dim; content: Content): FileMeta =
  ## Ported from `handle_thumbnail_file`.
  discard

proc handleContentFile*(mxc: Mxc<'_>; user: Option[string]; content: Content): FileMeta =
  ## Ported from `handle_content_file`.
  discard

proc handleLocation*(mxc: Mxc<'_>; user: Option[string]; location: string): FileMeta =
  ## Ported from `handle_location`.
  discard

proc locationRequest*(location: string): FileMeta =
  ## Ported from `location_request`.
  discard

proc handleFederationError*(mxc: Mxc<'_>; user: Option[string]; server: Option[string]; error: Error): Error =
  ## Ported from `handle_federation_error`.
  discard

proc fetchRemoteThumbnailLegacy*(body: media::get_content_thumbnail::v3::Request): media::get_content_thumbnail::v3::Response =
  ## Ported from `fetch_remote_thumbnail_legacy`.
  discard

proc fetchRemoteContentLegacy*(mxc: Mxc<'_>; allowRedirect: bool; timeoutMs: Duration): media::get_content::v3::Response =
  ## Ported from `fetch_remote_content_legacy`.
  discard

proc checkFetchAuthorized*(mxc: Mxc<'_>) =
  ## Ported from `check_fetch_authorized`.
  discard

proc checkLegacyFreeze*() =
  ## Ported from `check_legacy_freeze`.
  discard

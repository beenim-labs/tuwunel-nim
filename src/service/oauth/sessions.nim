## oauth/sessions — service module.
##
## Ported from Rust service/oauth/sessions.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/oauth/sessions.rs"
  RustCrate* = "service"

type
  Sessions* = ref object
    discard

type
  Session* = ref object
    idpId*: Option[string]
    sessId*: Option[SessionId]
    tokenType*: Option[string]
    accessToken*: Option[string]
    expiresIn*: Option[uint64]
    expiresAt*: Option[SystemTime]
    refreshToken*: Option[string]
    refreshTokenExpiresIn*: Option[uint64]
    refreshTokenExpiresAt*: Option[SystemTime]
    scope*: Option[string]

proc build*(args: crate::Args<'_>; providers: Providers) =
  ## Ported from `build`.
  discard

proc delete*(self: Sessions; sessId: string) =
  ## Ported from `delete`.
  discard

proc put*(self: Sessions; session: Session) =
  ## Ported from `put`.
  discard

proc getByUniqueId*(self: Sessions; uniqueId: string): Session =
  ## Ported from `get_by_unique_id`.
  discard

proc getByUser*(self: Sessions; userId: string): impl Stream<Item = Session> + Send =
  ## Ported from `get_by_user`.
  discard

proc get*(self: Sessions; sessId: string): Session =
  ## Ported from `get`.
  discard

proc getSessIdByUser*(self: Sessions; userId: string): impl Stream<Item = string> + Send =
  ## Ported from `get_sess_id_by_user`.
  discard

proc getSessIdByUniqueId*(self: Sessions; uniqueId: string): string =
  ## Ported from `get_sess_id_by_unique_id`.
  ""

proc users*(self: Sessions): impl Stream<Item = string> + Send =
  ## Ported from `users`.
  discard

proc stream*(self: Sessions): impl Stream<Item = Session> + Send =
  ## Ported from `stream`.
  discard

proc provider*(self: Sessions; session: Session): Provider =
  ## Ported from `provider`.
  discard

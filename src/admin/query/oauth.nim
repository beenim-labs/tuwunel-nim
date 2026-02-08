## query/oauth — admin module.
##
## Ported from Rust admin/query/oauth.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/query/oauth.rs"
  RustCrate* = "admin"

proc sessionOrUserId*(input: string): SessionOrstring =
  ## Ported from `session_or_user_id`.
  discard

proc oauthAssociate*(provider: string; userId: string; claim: seq[string]) =
  ## Ported from `oauth_associate`.
  discard

proc oauthListProviders*() =
  ## Ported from `oauth_list_providers`.
  discard

proc oauthListUsers*() =
  ## Ported from `oauth_list_users`.
  discard

proc oauthListSessions*(userId: Option[string]) =
  ## Ported from `oauth_list_sessions`.
  discard

proc oauthShowProvider*(id: ProviderId; config: bool) =
  ## Ported from `oauth_show_provider`.
  discard

proc oauthShowSession*(id: SessionId) =
  ## Ported from `oauth_show_session`.
  discard

proc oauthShowUser*(userId: string) =
  ## Ported from `oauth_show_user`.
  discard

proc oauthTokenInfo*(id: SessionId) =
  ## Ported from `oauth_token_info`.
  discard

proc oauthRevoke*(id: SessionOrstring) =
  ## Ported from `oauth_revoke`.
  discard

proc oauthDelete*(id: SessionOrstring; force: bool) =
  ## Ported from `oauth_delete`.
  discard

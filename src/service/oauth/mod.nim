## oauth/mod — service module.
##
## Ported from Rust service/oauth/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/oauth/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    providers*: Providers
    sessions*: Sessions

# import ./providers
# import ./sessions
# import ./user_info

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc deleteUserSessions*(self: Service; userId: string) =
  ## Ported from `delete_user_sessions`.
  discard

proc revokeUserTokens*(self: Service; userId: string) =
  ## Ported from `revoke_user_tokens`.
  discard

proc userSessions*(self: Service; userId: string): impl Stream<Item = (Provider> + Send =
  ## Ported from `user_sessions`.
  discard

proc requestUserinfo*(self: Service) =
  ## Ported from `request_userinfo`.
  discard

proc requestTokeninfo*(self: Service) =
  ## Ported from `request_tokeninfo`.
  discard

proc revokeToken*(self: Service) =
  ## Ported from `revoke_token`.
  discard

proc requestToken*(self: Service) =
  ## Ported from `request_token`.
  discard

proc uniqueId*() =
  ## Ported from `unique_id`.
  discard

proc uniqueIdSub*() =
  ## Ported from `unique_id_sub`.
  discard

proc uniqueIdIss*() =
  ## Ported from `unique_id_iss`.
  discard

proc uniqueIdIssSub*() =
  ## Ported from `unique_id_iss_sub`.
  discard

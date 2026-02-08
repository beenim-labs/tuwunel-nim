## session/sso — api module.
##
## Ported from Rust api/client/session/sso.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/session/sso.rs"
  RustCrate* = "api"

proc ssoLoginRoute*() =
  ## Ported from `sso_login_route`.
  discard

proc ssoLoginWithProviderRoute*() =
  ## Ported from `sso_login_with_provider_route`.
  discard

proc handleSsoLogin*(services: Services; Client: IpAddr; idpId: string; redirectUrl: string; loginToken: Option[string]): sso_login_with_provider::v3::Response =
  ## Ported from `handle_sso_login`.
  discard

proc ssoCallbackRoute*() =
  ## Ported from `sso_callback_route`.
  discard

proc registerUser*(services: Services; provider: Provider; session: Session; userinfo: UserInfo; userId: string) =
  ## Ported from `register_user`.
  discard

proc setAvatar*(services: Services; Provider: Provider; Session: Session; Userinfo: UserInfo; userId: string; avatarUrl: string) =
  ## Ported from `set_avatar`.
  discard

proc decideUserId*(services: Services; provider: Provider; userinfo: UserInfo; uniqueId: string): string =
  ## Ported from `decide_user_id`.
  ""

proc tryUserId*(services: Services; username: string; mayExist: bool): Option[string] =
  ## Ported from `try_user_id`.
  none(string)

proc parseUserId*(serverName: string; username: string): string =
  ## Ported from `parse_user_id`.
  ""

const
  RustPath* = "api/client/session/mod.rs"
  RustCrate* = "api"

import std/[json, options]

import api/client/session/[
  appservice,
  jwt,
  ldap,
  logout,
  password,
  refresh,
  sso,
  token,
]

export appservice, jwt, ldap, logout, password, refresh, sso, token

type
  LoginFlowConfig* = object
    loginWithPassword*: bool
    jwtEnabled*: bool
    loginViaExistingSession*: bool
    includeSso*: bool
    oauthAwarePreferred*: bool
    identityProviders*: seq[SsoProviderSummary]

proc defaultLoginFlowConfig*(): LoginFlowConfig =
  LoginFlowConfig(
    loginWithPassword: true,
    jwtEnabled: false,
    loginViaExistingSession: true,
    includeSso: false,
    oauthAwarePreferred: false,
    identityProviders: @[],
  )

proc loginTypesResponse*(cfg: LoginFlowConfig = defaultLoginFlowConfig()): JsonNode =
  result = %*{"flows": []}
  result["flows"].add(%*{"type": "m.login.application_service"})
  if cfg.jwtEnabled:
    result["flows"].add(%*{"type": "org.matrix.login.jwt"})
  if cfg.loginWithPassword:
    result["flows"].add(%*{"type": "m.login.password"})
  result["flows"].add(%*{
    "type": "m.login.token",
    "get_login_token": cfg.loginViaExistingSession
  })
  if cfg.includeSso or cfg.identityProviders.len > 0:
    result["flows"].add(ssoLoginFlow(cfg.identityProviders, cfg.oauthAwarePreferred))

proc loginResponse*(
  userId, accessToken, deviceId, homeServer: string;
  wellKnownBaseUrl = "";
  refreshToken = "";
  expiresInMs: Option[int64] = none(int64)
): JsonNode =
  result = %*{
    "user_id": userId,
    "access_token": accessToken,
    "device_id": deviceId,
    "home_server": homeServer
  }
  if wellKnownBaseUrl.len > 0:
    result["well_known"] = %*{
      "m.homeserver": {
        "base_url": wellKnownBaseUrl
      }
    }
  if refreshToken.len > 0:
    result["refresh_token"] = %refreshToken
  if expiresInMs.isSome:
    result["expires_in_ms"] = %expiresInMs.get()

const
  RustPath* = "api/client/session/sso.rs"
  RustCrate* = "api"

import std/[json, strutils, uri]

type
  SsoProviderSummary* = object
    id*: string
    brand*: string
    icon*: string
    name*: string

  SsoSessionCookie* = object
    sessionId*: string
    clientId*: string
    nonce*: string
    redirectUrl*: string
    callbackPath*: string
    maxAgeSeconds*: int

proc ssoProviderPayload*(provider: SsoProviderSummary): JsonNode =
  result = %*{
    "id": provider.id,
    "brand": provider.brand,
    "name": if provider.name.len > 0: provider.name else: provider.brand
  }
  if provider.icon.len > 0:
    result["icon"] = %provider.icon

proc ssoLoginFlow*(
  providers: openArray[SsoProviderSummary];
  oauthAwarePreferred = false
): JsonNode =
  result = %*{
    "type": "m.login.sso",
    "identity_providers": []
  }
  for provider in providers:
    result["identity_providers"].add(ssoProviderPayload(provider))
  if oauthAwarePreferred:
    result["org.matrix.msc3824.oauth_aware"] = %true

proc ssoLoginPathParts*(path: string): tuple[ok: bool, providerId: string] =
  for prefix in [
    "/_matrix/client/v3/login/sso/redirect",
    "/_matrix/client/r0/login/sso/redirect",
  ]:
    if path == prefix:
      return (true, "")
    if path.startsWith(prefix & "/"):
      return (true, decodeUrl(path[prefix.len + 1 .. ^1]))
  (false, "")

proc ssoCallbackProviderId*(path: string): string =
  for prefix in [
    "/_matrix/client/unstable/login/sso/callback/",
    "/_matrix/client/v3/login/sso/callback/",
    "/_matrix/client/r0/login/sso/callback/",
  ]:
    if path.startsWith(prefix):
      return decodeUrl(path[prefix.len .. ^1])
  ""

proc ssoCookie*(session: SsoSessionCookie): string =
  let path =
    if session.callbackPath.len > 0:
      session.callbackPath
    else:
      "/"
  "tuwunel_grant_session=client_id=" & encodeUrl(session.clientId) &
    "&state=" & encodeUrl(session.sessionId) &
    "&nonce=" & encodeUrl(session.nonce) &
    "&redirect_uri=" & encodeUrl(session.redirectUrl) &
    "; Path=" & path &
    "; Max-Age=" & $session.maxAgeSeconds &
    "; SameSite=None; Secure; HttpOnly"

proc ssoCallbackCheck*(
  state, code, cookieState, cookieNonce, sessionNonce: string
): tuple[ok: bool, errcode: string, message: string] =
  if state.len == 0:
    return (false, "M_FORBIDDEN", "Missing sess_id in callback.")
  if code.len == 0:
    return (false, "M_FORBIDDEN", "Missing code in callback.")
  if cookieState.len > 0 and cookieState != state:
    return (false, "M_UNAUTHORIZED", "Session ID " & state & " cookie mismatch.")
  if cookieNonce.len > 0 and sessionNonce.len > 0 and cookieNonce != sessionNonce:
    return (false, "M_UNAUTHORIZED", "Cookie nonce does not match session state.")
  (true, "", "")

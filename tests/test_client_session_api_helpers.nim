import std/[json, strutils, unittest]

import api/client/session/appservice as session_appservice
import api/client/session/jwt as session_jwt
import api/client/session/ldap as session_ldap
import api/client/session/logout as session_logout
import api/client/session/password as session_password
import api/client/session/refresh as session_refresh
import api/client/session/sso as session_sso
import api/client/session/token as session_token

suite "Client session API helpers":
  test "password helpers parse Matrix identifiers and preserve login denial reasons":
    let parsed = session_password.passwordLoginUser(%*{
      "identifier": {
        "type": "m.id.user",
        "user": "Alice"
      },
      "password": "secret"
    }, "localhost")
    check parsed.ok
    check parsed.userId == "@Alice:localhost"
    check parsed.lowercasedUserId == "@alice:localhost"

    let remote = session_password.passwordLoginUser(%*{
      "user": "@alice:remote.test",
      "password": "secret"
    }, "localhost")
    check not remote.ok
    check remote.errcode == "M_UNKNOWN"

    check not session_password.passwordLoginPolicy(accountOrigin = "appservice").ok
    check session_password.passwordLoginPolicy(passwordMatches = false).message == "Wrong username or password."
    check session_password.passwordLoginPolicy(hashEmpty = true).errcode == "M_USER_DEACTIVATED"

  test "appservice helpers extract target user and enforce token, namespace and local checks":
    let target = session_appservice.appserviceLoginUserIdFromBody(%*{
      "identifier": {
        "type": "m.id.user",
        "user": "bridge_user"
      }
    }, "@fallback:localhost", "localhost")
    check target == "@bridge_user:localhost"

    check session_appservice.appserviceLoginPolicy(
      "@bridge_user:localhost",
      "localhost",
      appserviceTokenPresent = false,
      namespaceMatches = true,
      userExists = true,
    ).errcode == "M_MISSING_TOKEN"

    check session_appservice.appserviceLoginPolicy(
      "@bridge_user:localhost",
      "localhost",
      appserviceTokenPresent = true,
      namespaceMatches = false,
      userExists = true,
    ).errcode == "M_EXCLUSIVE"

    let allowed = session_appservice.appserviceLoginPolicy(
      "@bridge_user:localhost",
      "localhost",
      appserviceTokenPresent = true,
      namespaceMatches = true,
      userExists = true,
    )
    check allowed.ok
    check allowed.userId == "@bridge_user:localhost"

  test "token, refresh and logout helpers keep Matrix response shapes":
    check session_token.tokenLoginPolicy(false).message == "Token login is not enabled."
    check session_token.loginTokenIssuePolicy(false, true, true).errcode == "M_FORBIDDEN"
    check session_token.loginTokenIssuePolicy(true, true, false).errcode == "M_USER_DEACTIVATED"

    let loginToken = session_token.loginTokenPayload("login_token", 120000)
    check loginToken["login_token"].getStr == "login_token"
    check loginToken["expires_in_ms"].getInt == 120000

    check not session_refresh.refreshTokenFormatCheck("bad").ok
    check session_refresh.refreshTokenFormatCheck("refresh_ok").ok
    let refreshed = session_refresh.refreshTokenPayload("access", "refresh_next", 604800000)
    check refreshed["access_token"].getStr == "access"
    check refreshed["refresh_token"].getStr == "refresh_next"
    check refreshed["expires_in_ms"].getInt == 604800000

    check session_logout.logoutResponse().len == 0
    check session_logout.logoutAllResponse().len == 0

  test "jwt and ldap helpers mirror local-user and account-origin policy":
    check session_jwt.jwtLoginPolicy(false).errcode == "M_UNAUTHORIZED"
    let jwtUser = session_jwt.jwtSubjectUserId("Alice", "localhost")
    check jwtUser.ok
    check jwtUser.userId == "@alice:localhost"
    check session_jwt.jwtUnknownUserPolicy(false, false, "@alice:localhost").errcode == "M_NOT_FOUND"
    check session_jwt.jwtUnknownUserPolicy(false, true, "@alice:localhost").ok

    let bindResult = session_ldap.ldapBindDn("uid={username},ou=people,dc=example", "Alice")
    check bindResult.ok
    check bindResult.directBind
    check bindResult.userDn == "uid=alice,ou=people,dc=example"
    check session_ldap.ldapAccountOrigin() == "ldap"
    check session_ldap.ldapAdminSyncAction(true, true, false) == "grant"
    check session_ldap.ldapAdminSyncAction(true, false, true) == "revoke"
    check session_ldap.ldapAdminSyncAction(false, true, false) == "none"

  test "sso helpers build provider flow, route parts, cookie and callback checks":
    let provider = session_sso.SsoProviderSummary(
      id: "test-idp",
      brand: "github",
      icon: "mxc://localhost/icon",
      name: "GitHub"
    )
    let providerPayload = session_sso.ssoProviderPayload(provider)
    check providerPayload["id"].getStr == "test-idp"
    check providerPayload["brand"].getStr == "github"
    check providerPayload["name"].getStr == "GitHub"
    check providerPayload["icon"].getStr == "mxc://localhost/icon"

    let flow = session_sso.ssoLoginFlow([provider], oauthAwarePreferred = true)
    check flow["type"].getStr == "m.login.sso"
    check flow["identity_providers"][0]["id"].getStr == "test-idp"
    check flow["org.matrix.msc3824.oauth_aware"].getBool

    let barePath = session_sso.ssoLoginPathParts("/_matrix/client/v3/login/sso/redirect")
    check barePath.ok
    check barePath.providerId == ""
    let idpPath = session_sso.ssoLoginPathParts("/_matrix/client/v3/login/sso/redirect/test-idp")
    check idpPath.ok
    check idpPath.providerId == "test-idp"
    check session_sso.ssoCallbackProviderId("/_matrix/client/unstable/login/sso/callback/test-idp") == "test-idp"

    let cookie = session_sso.ssoCookie(session_sso.SsoSessionCookie(
      sessionId: "sess",
      clientId: "client",
      nonce: "nonce",
      redirectUrl: "https://client.example/done",
      callbackPath: "/_matrix/client/unstable/login/sso/callback/test-idp",
      maxAgeSeconds: 300,
    ))
    check cookie.contains("tuwunel_grant_session=")
    check cookie.contains("SameSite=None")
    check cookie.contains("HttpOnly")

    check not session_sso.ssoCallbackCheck("", "code", "", "", "").ok
    check session_sso.ssoCallbackCheck("sess", "code", "sess", "nonce", "nonce").ok
    check session_sso.ssoCallbackCheck("sess", "code", "other", "nonce", "nonce").errcode == "M_UNAUTHORIZED"

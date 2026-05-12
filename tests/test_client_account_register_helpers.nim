import std/[json, options, unittest]

import api/client/account as client_account
import api/client/openid as client_openid
import api/client/register as client_register
import api/client/unversioned as client_unversioned

suite "Client account and registration API helpers":
  test "account helpers preserve whoami, 3PID and deactivate response shapes":
    let whoami = client_account.whoamiPayload("@alice:localhost", "DEV1")
    check whoami["user_id"].getStr == "@alice:localhost"
    check whoami["device_id"].getStr == "DEV1"
    check not whoami["is_guest"].getBool

    let appserviceWhoami = client_account.whoamiPayload("@bridge:localhost", "")
    check appserviceWhoami["user_id"].getStr == "@bridge:localhost"
    check not appserviceWhoami.hasKey("device_id")

    check client_account.changePasswordPolicy("new-password").ok
    check client_account.changePasswordPolicy("", authenticated = true).errcode == "M_INVALID_PARAM"
    check client_account.changePasswordResponse().len == 0
    check client_account.deactivatePolicy().ok
    check client_account.deactivateResponse()["id_server_unbind_result"].getStr == "no-support"
    check client_account.accountThreepidsPayload()["threepids"].len == 0
    check client_account.request3pidManagementTokenPolicy().errcode == "M_THREEPID_DENIED"

  test "OpenID helpers enforce same-user token requests and Matrix token payload":
    check client_openid.openIdRequestPolicy("@alice:localhost", "@alice:localhost").ok
    let denied = client_openid.openIdRequestPolicy("@alice:localhost", "@bob:localhost")
    check not denied.ok
    check denied.errcode == "M_INVALID_PARAM"

    let token = client_openid.openIdTokenPayload("oidc_token", "localhost", expiresIn = 600)
    check token["access_token"].getStr == "oidc_token"
    check token["token_type"].getStr == "Bearer"
    check token["matrix_server_name"].getStr == "localhost"
    check token["expires_in"].getInt == 600

  test "registration username parsing follows Matrix localpart and appservice cases":
    let normalized = client_register.registrationUserIdFromUsername("Alice", "localhost")
    check normalized.ok
    check normalized.userId == "@alice:localhost"
    check normalized.username == "alice"

    let full = client_register.registrationUserIdFromUsername("@alice:localhost", "localhost")
    check full.ok
    check full.username == "alice"

    let invalid = client_register.registrationUserIdFromUsername("bad name", "localhost")
    check not invalid.ok
    check invalid.errcode == "M_INVALID_USERNAME"

    let remote = client_register.registrationUserIdFromUsername("@alice:remote.test", "localhost")
    check not remote.ok
    check remote.errcode == "M_INVALID_USERNAME"

    let ircCompat = client_register.registrationUserIdFromUsername(
      "Bridge User",
      "localhost",
      preserveCase = true,
      relaxed = true,
    )
    check ircCompat.ok
    check ircCompat.userId == "@Bridge User:localhost"
    check client_register.isMatrixAppserviceIrc("matrix-appservice-irc")

  test "registration availability and policy helpers match Rust denial branches":
    check client_register.registrationAvailability("alice", "localhost").ok

    let forbidden = client_register.registrationAvailability("root", "localhost", forbiddenUsername = true)
    check not forbidden.ok
    check forbidden.errcode == "M_FORBIDDEN"

    let taken = client_register.registrationAvailability("alice", "localhost", userExists = true)
    check not taken.ok
    check taken.errcode == "M_USER_IN_USE"

    let reserved = client_register.registrationAvailability("bridge_alice", "localhost", exclusiveReserved = true)
    check not reserved.ok
    check reserved.errcode == "M_EXCLUSIVE"

    let outsideNamespace = client_register.registrationAvailability(
      "alice",
      "localhost",
      appservicePresent = true,
      appserviceMatches = false,
    )
    check not outsideNamespace.ok
    check outsideNamespace.message == "Username is not in an appservice namespace."

    check client_register.registerPolicy(allowRegistration = false, isAppservice = true).ok
    check client_register.registerPolicy(allowRegistration = false).errcode == "M_FORBIDDEN"
    check client_register.registerPolicy(isGuest = true, allowGuestRegistration = false).errcode == "M_GUEST_ACCESS_FORBIDDEN"
    check client_register.appserviceRegisterPolicy(false, true).errcode == "M_MISSING_TOKEN"
    check client_register.appserviceRegisterPolicy(true, false).errcode == "M_EXCLUSIVE"

  test "registration response, token validity and unversioned path helpers are stable":
    let response = client_register.registerResponse(
      "@alice:localhost",
      "localhost",
      accessToken = "access",
      deviceId = "DEV1",
      refreshToken = "refresh_token",
      expiresInMs = some(604800000'i64),
    )
    check response["user_id"].getStr == "@alice:localhost"
    check response["home_server"].getStr == "localhost"
    check response["access_token"].getStr == "access"
    check response["device_id"].getStr == "DEV1"
    check response["refresh_token"].getStr == "refresh_token"
    check response["expires_in_ms"].getInt == 604800000

    check client_register.registrationTokenValidityPolicy(false).errcode == "M_FORBIDDEN"
    check client_register.registrationTokenValidityPayload(true)["valid"].getBool

    check client_unversioned.trimClientPath("/_matrix/client/v3/register/available") == "register/available"
    check client_unversioned.trimClientPath("/_matrix/client/r0/account/3pid") == "account/3pid"
    check client_unversioned.isClientApiPath("/_matrix/client/unstable/login/sso/callback/idp")
    check not client_unversioned.isClientApiPath("/_matrix/federation/v1/version")

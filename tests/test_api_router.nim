import std/[json, options, strutils, unittest]
import api/router
import api/router/request
import api/router/state
import api/generated_route_runtime

suite "API router behavioral compatibility":
  test "request parsing and query extraction":
    var req = initApiRequest("get", "/_matrix/client/v3/sync?since=t1&timeout=10", routeName = "sync_events_route")
    check req.httpMethod == "GET"
    check req.path == "/_matrix/client/v3/sync"
    check req.getQueryParam("since").get == "t1"
    check req.getQueryParam("timeout").get == "10"

    req.setQueryParam("set_presence", "offline")
    check req.getQueryParam("set_presence").get == "offline"

  test "register/login/logout flow is stateful":
    let router = initApiRouter()

    var registerReq = initApiRequest(
      "POST",
      "/_matrix/client/v3/register",
      routeName = "register_route",
      body = """{"username":"alice","password":"secret"}""",
    )
    let registerRes = router.dispatch(registerReq)
    check registerRes.status == 200
    check registerRes.body["user_id"].getStr == "@alice:tuwunel-nim"
    let token = registerRes.body["access_token"].getStr
    check token.len > 0
    check router.state.localUserCount() == 1

    var whoamiReq = initApiRequest("GET", "/_matrix/client/v3/account/whoami", routeName = "whoami_route")
    whoamiReq = whoamiReq.withAccessToken(token)
    let whoamiOk = router.dispatch(whoamiReq)
    check whoamiOk.status == 200
    check whoamiOk.body["user_id"].getStr == "@alice:tuwunel-nim"
    check whoamiOk.body["device_id"].getStr.startsWith("NIM-")

    var logoutReq = initApiRequest("POST", "/_matrix/client/v3/logout", routeName = "logout_route")
    logoutReq = logoutReq.withAccessToken(token)
    let logoutRes = router.dispatch(logoutReq)
    check logoutRes.status == 200

    let whoamiAfter = router.dispatch(whoamiReq)
    check whoamiAfter.status == 401
    check whoamiAfter.errcode == "M_UNKNOWN_TOKEN"

  test "whoami still enforces auth":
    let router = initApiRouter()
    let denied = router.dispatchRouteName("whoami_route")
    check denied.status == 401
    check denied.errcode == "M_UNAUTHORIZED"

  test "versions and login flows expose matrix-compatible structures":
    let router = initApiRouter()

    let versions = router.dispatchRouteName("get_supported_versions_route")
    check versions.status == 200
    check versions.body["versions"].kind == JArray
    check versions.body["versions"].len > 0
    check versions.body["unstable_features"].kind == JObject

    let loginTypes = router.dispatchRouteName("get_login_types_route")
    check loginTypes.status == 200
    check loginTypes.body["flows"].kind == JArray
    check loginTypes.body["flows"].len >= 1

  test "duplicate route names resolve to federation variant when federated":
    let router = initApiRouter()

    let client = router.dispatchRouteName("get_public_rooms_route", accessTokenPresent = true)
    check client.status == 200
    check client.routeKind == rkClient

    let fed = router.dispatchRouteName("get_public_rooms_route", federationAuthenticated = true)
    check fed.status == 200
    check fed.routeKind == rkServer

  test "well-known and state accounting":
    let router = initApiRouter()
    let wk = router.dispatchRouteName("/.well-known/matrix/server")
    check wk.status == 200
    check wk.body["m.server"].getStr.len > 0

    let unknown = router.dispatchRouteName("unknown_route")
    check unknown.status == 404
    check router.state.totalRequests == 2
    check statusHits(router.state, 200) == 1
    check statusHits(router.state, 404) == 1

  test "register availability and login validation":
    let router = initApiRouter()

    let before = router.dispatch(initApiRequest(
      "GET",
      "/_matrix/client/v3/register/available?username=bob",
      routeName = "get_register_available_route",
    ))
    check before.status == 200
    check before.body["available"].getBool

    discard router.dispatch(initApiRequest(
      "POST",
      "/_matrix/client/v3/register",
      routeName = "register_route",
      body = """{"username":"bob","password":"hunter2"}""",
    ))

    let after = router.dispatch(initApiRequest(
      "GET",
      "/_matrix/client/v3/register/available?username=bob",
      routeName = "get_register_available_route",
    ))
    check after.status == 400
    check after.errcode == "M_USER_IN_USE"

    let badLogin = router.dispatch(initApiRequest(
      "POST",
      "/_matrix/client/v3/login",
      routeName = "login_route",
      body = """{"type":"m.login.password","user":"@bob:tuwunel-nim","password":"wrong"}""",
    ))
    check badLogin.status == 403
    check badLogin.errcode == "M_FORBIDDEN"

  test "profile, devices, password, and deactivate flows":
    let router = initApiRouter()

    let registerRes = router.dispatch(initApiRequest(
      "POST",
      "/_matrix/client/v3/register",
      routeName = "register_route",
      body = """{"username":"carol","password":"initpw","device_id":"DEV1","initial_device_display_name":"Carol Phone"}""",
    ))
    check registerRes.status == 200
    let token = registerRes.body["access_token"].getStr

    var setDisplayReq = initApiRequest(
      "PUT",
      "/_matrix/client/v3/profile/@carol:tuwunel-nim/displayname",
      routeName = "set_displayname_route",
      body = """{"displayname":"Carol A."}""",
    )
    setDisplayReq = setDisplayReq.withAccessToken(token)
    check router.dispatch(setDisplayReq).status == 200

    var setAvatarReq = initApiRequest(
      "PUT",
      "/_matrix/client/v3/profile/@carol:tuwunel-nim/avatar_url",
      routeName = "set_avatar_url_route",
      body = """{"avatar_url":"mxc://tuwunel-nim/carol"}""",
    )
    setAvatarReq = setAvatarReq.withAccessToken(token)
    check router.dispatch(setAvatarReq).status == 200

    var setPresenceReq = initApiRequest(
      "PUT",
      "/_matrix/client/v3/presence/@carol:tuwunel-nim/status",
      routeName = "set_presence_route",
      body = """{"presence":"online"}""",
    )
    setPresenceReq = setPresenceReq.withAccessToken(token)
    check router.dispatch(setPresenceReq).status == 200

    var getProfileReq = initApiRequest(
      "GET",
      "/_matrix/client/v3/profile/@carol:tuwunel-nim",
      routeName = "get_profile_route",
    )
    getProfileReq = getProfileReq.withAccessToken(token)
    let profile = router.dispatch(getProfileReq)
    check profile.status == 200
    check profile.body["displayname"].getStr == "Carol A."
    check profile.body["avatar_url"].getStr == "mxc://tuwunel-nim/carol"
    check profile.body["presence"].getStr == "online"

    var getDevicesReq = initApiRequest(
      "GET",
      "/_matrix/client/v3/devices",
      routeName = "get_devices_route",
    )
    getDevicesReq = getDevicesReq.withAccessToken(token)
    let devices = router.dispatch(getDevicesReq)
    check devices.status == 200
    check devices.body["devices"].kind == JArray
    check devices.body["devices"].len == 1
    check devices.body["devices"][0]["device_id"].getStr == "DEV1"

    var updateDeviceReq = initApiRequest(
      "PUT",
      "/_matrix/client/v3/devices/DEV1?device_id=DEV1",
      routeName = "update_device_route",
      body = """{"display_name":"Carol Mobile"}""",
    )
    updateDeviceReq = updateDeviceReq.withAccessToken(token)
    check router.dispatch(updateDeviceReq).status == 200

    var getDeviceReq = initApiRequest(
      "GET",
      "/_matrix/client/v3/devices/DEV1?device_id=DEV1",
      routeName = "get_device_route",
    )
    getDeviceReq = getDeviceReq.withAccessToken(token)
    let device = router.dispatch(getDeviceReq)
    check device.status == 200
    check device.body["display_name"].getStr == "Carol Mobile"

    let loginRes = router.dispatch(initApiRequest(
      "POST",
      "/_matrix/client/v3/login",
      routeName = "login_route",
      body = """{"type":"m.login.password","user":"@carol:tuwunel-nim","password":"initpw","device_id":"DEV2"}""",
    ))
    check loginRes.status == 200
    let token2 = loginRes.body["access_token"].getStr
    check token2.len > 0

    var deleteDevicesReq = initApiRequest(
      "POST",
      "/_matrix/client/v3/delete_devices",
      routeName = "delete_devices_route",
      body = """{"devices":["DEV2"]}""",
    )
    deleteDevicesReq = deleteDevicesReq.withAccessToken(token)
    let deleted = router.dispatch(deleteDevicesReq)
    check deleted.status == 200
    check deleted.body["revoked"].getInt == 1

    var changePwReq = initApiRequest(
      "POST",
      "/_matrix/client/v3/account/password",
      routeName = "change_password_route",
      body = """{"new_password":"newpw","logout_devices":false}""",
    )
    changePwReq = changePwReq.withAccessToken(token)
    check router.dispatch(changePwReq).status == 200

    let badOldLogin = router.dispatch(initApiRequest(
      "POST",
      "/_matrix/client/v3/login",
      routeName = "login_route",
      body = """{"type":"m.login.password","user":"@carol:tuwunel-nim","password":"initpw"}""",
    ))
    check badOldLogin.status == 403

    let newLogin = router.dispatch(initApiRequest(
      "POST",
      "/_matrix/client/v3/login",
      routeName = "login_route",
      body = """{"type":"m.login.password","user":"@carol:tuwunel-nim","password":"newpw"}""",
    ))
    check newLogin.status == 200

    var deactivateReq = initApiRequest(
      "POST",
      "/_matrix/client/v3/account/deactivate",
      routeName = "deactivate_route",
      body = """{"erase":true}""",
    )
    deactivateReq = deactivateReq.withAccessToken(token)
    let deactivated = router.dispatch(deactivateReq)
    check deactivated.status == 200
    check deactivated.body["id_server_unbind_result"].getStr == "success"

    let postDeactivateLogin = router.dispatch(initApiRequest(
      "POST",
      "/_matrix/client/v3/login",
      routeName = "login_route",
      body = """{"type":"m.login.password","user":"@carol:tuwunel-nim","password":"newpw"}""",
    ))
    check postDeactivateLogin.status == 403

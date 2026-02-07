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

  test "whoami enforces auth and returns payload":
    let router = initApiRouter()

    let denied = router.dispatchRouteName("whoami_route")
    check denied.status == 401
    check denied.errcode == "M_UNAUTHORIZED"

    let ok = router.dispatchRouteName("whoami_route", accessTokenPresent = true)
    check ok.status == 200
    check ok.ok
    check ok.body["user_id"].getStr.len > 0
    check ok.body["device_id"].getStr.startsWith("NIM-")

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

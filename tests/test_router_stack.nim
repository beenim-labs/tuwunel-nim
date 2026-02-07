import std/unittest
import std/options
import router/[request, layers, router, run]
import router/serve

suite "Router stack compatibility":
  test "request headers and auth flags":
    var req = initRouterRequest("get", "/_matrix/client/v3/versions", routeName = "get_supported_versions_route")
    req.setHeader("X-Test", "1")

    check req.httpMethod == "GET"
    check req.getHeader("x-test").get == "1"
    check not req.hasAccessToken()

    req = req.withAccessToken("abc")
    check req.hasAccessToken()

  test "layer gating for auth route":
    let req = initRouterRequest("GET", "/whoami", routeName = "whoami_route")
    let report = applyRouterLayers(req)

    check report.requiresAuth
    check not report.allowed

  test "router dispatch for public and auth routes":
    var engine = initRouterEngine()

    let publicDispatch = engine.dispatchRouteName("get_supported_versions_route")
    check publicDispatch.result.ok
    check publicDispatch.result.status == 200

    let authDenied = engine.dispatchRouteName("whoami_route")
    check not authDenied.result.ok
    check authDenied.result.status == 401

    let authAllowed = engine.dispatchRouteName("whoami_route", accessTokenPresent = true)
    check authAllowed.result.ok
    check authAllowed.result.status == 200

  test "batch run reports":
    let report = runRouterRouteNames(@[
      "get_supported_versions_route",
      "whoami_route",
      "unknown_route",
    ])

    check report.total == 3
    check report.ok == 1
    check report.denied == 2
    check report.status200 == 1
    check report.status401 == 1
    check report.status404 == 1

  test "serve mode wrappers execute batch":
    let reqs = @[
      initRouterRequest("GET", "/versions", routeName = "get_supported_versions_route"),
      initRouterRequest("GET", "/whoami", routeName = "whoami_route"),
    ]

    var cfg = defaultRouterServeConfig()
    cfg.mode = rsmPlain
    let plainReport = runServeBatch(reqs, cfg)
    check plainReport.total == 2

    cfg.mode = rsmTls
    let tlsReport = runServeBatch(reqs, cfg)
    check tlsReport.total == 2

    cfg.mode = rsmUnix
    let unixReport = runServeBatch(reqs, cfg)
    check unixReport.total == 2

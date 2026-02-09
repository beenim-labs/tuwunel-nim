import std/[sets, tables, unittest]
import api/generated_route_inventory
import api/generated_route_runtime

suite "Route runtime compatibility scaffold":
  test "all extracted routes are registered":
    let registry = routeRegistry()
    var uniqueNames = initHashSet[string]()
    for spec in RouteSpecs:
      uniqueNames.incl(spec.name)

    check RouteSpecs.len == TotalRouteCount
    check RegisteredRouteCount == TotalRouteCount
    check routeCountByKind(rkClient) == ClientRumaRouteCount
    check routeCountByKind(rkServer) == ServerRumaRouteCount
    check routeCountByKind(rkManual) == ManualRouteCount
    check len(registry) == uniqueNames.len

    for route in ClientRumaRoutes:
      check registry.hasKey(route)
    for route in ServerRumaRoutes:
      check registry.hasKey(route)
    for route in ManualRoutes:
      check registry.hasKey(route)

  test "unknown route follows matrix unrecognized error shape":
    let res = dispatchRoute("unknown_route_name")
    check not res.ok
    check res.status == 404
    check res.error.status == 404
    check res.error.errcode == "M_UNRECOGNIZED"

  test "client auth gating and routed fallback":
    let unauth = dispatchRoute("whoami_route")
    check unauth.status == 401
    check unauth.error.errcode == "M_UNAUTHORIZED"

    let publicRoute = dispatchRoute("login_route")
    check publicRoute.status == 501
    check publicRoute.error.errcode == "M_NOT_YET_IMPLEMENTED"

    let authed = dispatchRoute("whoami_route", accessTokenPresent = true)
    check authed.status == 501
    check authed.authorized

  test "server route federation auth gating":
    check ServerRumaRoutes.len > 0
    let fedRoute = ServerRumaRoutes[0]

    let missingFedAuth = dispatchRoute(fedRoute)
    check missingFedAuth.status == 401
    check missingFedAuth.error.errcode == "M_UNAUTHORIZED"

    let fedAuthed = dispatchRoute(fedRoute, federationAuthenticated = true)
    check fedAuthed.status == 501
    check fedAuthed.authorized

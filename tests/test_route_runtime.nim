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

  test "client auth gating and routed dispatch":
    let unauth = dispatchRoute("whoami_route")
    check unauth.status == 401
    check unauth.error.errcode == "M_UNAUTHORIZED"

    let publicRoute = dispatchRoute("login_route")
    check publicRoute.status == 200
    check publicRoute.ok
    check publicRoute.authorized

    let authed = dispatchRoute("whoami_route", accessTokenPresent = true)
    check authed.status == 200
    check authed.ok
    check authed.authorized

  test "server route federation auth gating":
    let missingFedAuth = dispatchRoute("get_server_version_route")
    check missingFedAuth.status == 401
    check missingFedAuth.error.errcode == "M_UNAUTHORIZED"

    let fedAuthed = dispatchRoute("get_server_version_route", federationAuthenticated = true)
    check fedAuthed.status == 200
    check fedAuthed.ok
    check fedAuthed.authorized

  test "duplicate client/server names prefer federation route with federation auth":
    let missingAuth = dispatchRoute("get_public_rooms_route")
    check missingAuth.status == 401

    let clientAuthed = dispatchRoute("get_public_rooms_route", accessTokenPresent = true)
    check clientAuthed.status == 200
    check clientAuthed.ok
    check clientAuthed.routeKind == rkClient

    let federationAuthed = dispatchRoute("get_public_rooms_route", federationAuthenticated = true)
    check federationAuthed.status == 200
    check federationAuthed.ok
    check federationAuthed.routeKind == rkServer

  test "federation route is runtime implemented":
    let fedAuthed = dispatchRoute("get_openid_userinfo_route", federationAuthenticated = true)
    check fedAuthed.status == 200
    check fedAuthed.ok
    check fedAuthed.authorized

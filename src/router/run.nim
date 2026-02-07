import router
import request

const
  RustPath* = "router/run.rs"
  RustCrate* = "router"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  RouterRunReport* = object
    total*: int
    ok*: int
    denied*: int
    unknown*: int
    status200*: int
    status401*: int
    status404*: int

proc runRouterRequests*(
    engine: var RouterEngine; requests: openArray[RouterRequest]): RouterRunReport =
  result = RouterRunReport()
  for req in requests:
    let dispatched = engine.dispatch(req)
    inc result.total

    case dispatched.result.status
    of 200:
      inc result.status200
    of 401:
      inc result.status401
    of 404:
      inc result.status404
    else:
      discard

    if dispatched.result.ok:
      inc result.ok
    else:
      inc result.denied
      if dispatched.result.status == 404:
        inc result.unknown

proc runRouterRouteNames*(
    routeNames: openArray[string]; accessTokenPresent = false; federationAuthenticated = false): RouterRunReport =
  var engine = initRouterEngine()
  var requests: seq[RouterRequest] = @[]
  for routeName in routeNames:
    var req = initRouterRequest("GET", routeName, routeName = routeName)
    if accessTokenPresent:
      req = req.withAccessToken("compat-token")
    if federationAuthenticated:
      req = req.withFederationAuth("compat-origin")
    requests.add(req)
  runRouterRequests(engine, requests)

import std/tables
import api/generated_route_runtime
import layers
import request

const
  RustPath* = "router/router.rs"
  RustCrate* = "router"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  RouterEngine* = object
    registry*: RouteRegistry
    layers*: seq[RouterLayer]
    dispatchCount*: int
    denialCount*: int
    statusCount*: Table[int, int]

  RouterDispatch* = object
    report*: RouterLayerReport
    result*: RouteDispatchResult

proc initRouterEngine*(layers = defaultRouterLayers()): RouterEngine =
  RouterEngine(
    registry: routeRegistry(),
    layers: layers,
    dispatchCount: 0,
    denialCount: 0,
    statusCount: initTable[int, int](),
  )

proc markStatus(engine: var RouterEngine; status: int) =
  let current = engine.statusCount.getOrDefault(status, 0)
  engine.statusCount[status] = current + 1

proc dispatch*(engine: var RouterEngine; req: RouterRequest): RouterDispatch =
  let report = applyRouterLayers(req)
  inc engine.dispatchCount

  let dispatchResult = dispatchRoute(
    report.routeName,
    accessTokenPresent = req.hasAccessToken(),
    federationAuthenticated = req.hasFederationAuth(),
  )

  if not dispatchResult.ok:
    inc engine.denialCount

  engine.markStatus(dispatchResult.status)
  RouterDispatch(report: report, result: dispatchResult)

proc dispatchRouteName*(
    engine: var RouterEngine; routeName: string; accessTokenPresent = false; federationAuthenticated = false): RouterDispatch =
  var req = initRouterRequest(httpMethod = "GET", path = routeName, routeName = routeName)
  if accessTokenPresent:
    req = req.withAccessToken("compat-token")
  if federationAuthenticated:
    req = req.withFederationAuth("compat-origin")
  engine.dispatch(req)

proc statusHits*(engine: RouterEngine; status: int): int =
  engine.statusCount.getOrDefault(status, 0)

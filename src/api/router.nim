import std/strformat
import api/generated_route_runtime
import api/router/request
import api/router/handler
import api/router/response
import api/router/state

const
  RustPath* = "api/router.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  ApiRouter* = ref object
    state*: ApiRouterState
    handlers*: ApiHandlerRegistry

proc initApiRouter*(): ApiRouter =
  new(result)
  result.state = initApiRouterState()
  result.handlers = defaultHandlerRegistry()

proc dispatch*(router: ApiRouter; req: ApiRequest): ApiResponse =
  let resp = dispatchApiRequest(req, router.handlers)
  router.state.record(resp)
  resp

proc dispatchRouteName*(
    router: ApiRouter; routeName: string; accessTokenPresent = false; federationAuthenticated = false;
    appserviceToken = ""; uiaaSession = ""): ApiResponse =
  var req = initApiRequest("GET", routeName, routeName = routeName)
  if accessTokenPresent:
    req = req.withAccessToken("compat-token")
  if federationAuthenticated:
    req = req.withFederationOrigin("compat-origin")
  if appserviceToken.len > 0:
    req = req.withAppserviceToken(appserviceToken)
  if uiaaSession.len > 0:
    req = req.withUiaaSession(uiaaSession)
  router.dispatch(req)

proc knownRouteCount*(router: ApiRouter): int =
  discard router
  RegisteredRouteCount

proc runtimeImplementedRouteCount*(router: ApiRouter): int =
  discard router
  RuntimeImplementedRouteCount

proc summaryLine*(router: ApiRouter): string =
  fmt"total={router.state.totalRequests} ok={router.state.okResponses} denied={router.state.deniedResponses} " &
    fmt"last_route={router.state.lastRoute} last_status={router.state.lastStatus}"

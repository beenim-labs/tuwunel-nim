import api/generated_route_runtime
import api/router/request
import api/router/auth/[appservice, server, uiaa]

const
  RustPath* = "api/router/auth.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  ApiAuthContext* = object
    accessTokenPresent*: bool
    federationAuthenticated*: bool
    appserviceAuthenticated*: bool
    uiaaCompleted*: bool

  ApiAuthDecision* = object
    allowed*: bool
    reason*: string

proc buildAuthContext*(req: ApiRequest): ApiAuthContext =
  let serverAuth = evaluateServerAuth(req)
  let appserviceAuth = evaluateAppserviceAuth(req)
  let uiaa = evaluateUiaa(req)
  ApiAuthContext(
    accessTokenPresent: req.hasAccessToken(),
    federationAuthenticated: serverAuth.authenticated,
    appserviceAuthenticated: appserviceAuth.authenticated,
    uiaaCompleted: uiaa.completed,
  )

proc checkRouteAuthorization*(spec: RouteSpec; ctx: ApiAuthContext): ApiAuthDecision =
  if spec.federationOnly:
    if ctx.federationAuthenticated:
      return ApiAuthDecision(allowed: true, reason: "")
    return ApiAuthDecision(allowed: false, reason: "missing federation authentication")

  if spec.requiresAuth:
    if ctx.accessTokenPresent or ctx.appserviceAuthenticated:
      return ApiAuthDecision(allowed: true, reason: "")
    return ApiAuthDecision(allowed: false, reason: "missing access token authentication")

  ApiAuthDecision(allowed: true, reason: "")

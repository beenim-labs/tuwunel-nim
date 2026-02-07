import std/[json, tables]
import api/generated_route_runtime
import api/router/args
import api/router/auth
import api/router/request
import api/router/response

const
  RustPath* = "api/router/handler.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"
  CompatServerName = "tuwunel-nim"
  CompatServerVersion = "0.1.0"
  CompatUserId = "@compat:tuwunel-nim"

type
  ApiRouteHandler* = proc(
    req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse {.closure.}

  ApiHandlerRegistry* = Table[string, ApiRouteHandler]

proc routeKindLabel(kind: RouteKind): string =
  case kind
  of rkClient:
    "client"
  of rkServer:
    "server"
  of rkManual:
    "manual"
  of rkUnknown:
    "unknown"

proc asJsonRouteSummary(spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): JsonNode =
  result = newJObject()
  result["route"] = %spec.name
  result["kind"] = %routeKindLabel(spec.kind)
  result["requires_auth"] = %spec.requiresAuth
  result["federation_only"] = %spec.federationOnly
  result["path_segments"] = %routeArgs.pathSegments.len
  result["query_params"] = %routeArgs.queryParams.len
  result["access_token"] = %ctx.accessTokenPresent
  result["federation"] = %ctx.federationAuthenticated

proc versionsHandler(req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  discard routeArgs
  discard ctx
  var payload = newJObject()
  payload["versions"] = %*[
    "r0.0.1",
    "r0.6.1",
    "v1.1",
    "v1.2",
    "v1.3",
    "v1.4",
    "v1.5",
    "v1.6",
    "v1.7",
    "v1.8",
    "v1.9",
    "v1.10",
    "v1.11",
  ]
  payload["unstable_features"] = newJObject()
  successResponse(spec.name, spec.kind, payload)

proc loginTypesHandler(req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  discard routeArgs
  discard ctx
  var passwordFlow = newJObject()
  passwordFlow["type"] = %"m.login.password"
  var tokenFlow = newJObject()
  tokenFlow["type"] = %"m.login.token"
  var payload = newJObject()
  payload["flows"] = %*[passwordFlow, tokenFlow]
  successResponse(spec.name, spec.kind, payload)

proc whoamiHandler(req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard routeArgs
  var payload = newJObject()
  payload["user_id"] = %CompatUserId
  if req.hasAccessToken():
    payload["device_id"] = %"NIM-DEVICE"
  else:
    payload["device_id"] = %"NIM-ANON"
  payload["is_guest"] = %false
  payload["federation_authenticated"] = %ctx.federationAuthenticated
  successResponse(spec.name, spec.kind, payload)

proc serverVersionHandler(req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  discard routeArgs
  discard ctx
  var server = newJObject()
  server["name"] = %CompatServerName
  server["version"] = %CompatServerVersion
  var payload = newJObject()
  payload["server"] = server
  successResponse(spec.name, spec.kind, payload)

proc wellKnownServerHandler(req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  discard routeArgs
  discard ctx
  var payload = newJObject()
  payload["m.server"] = %"localhost:8448"
  successResponse(spec.name, spec.kind, payload)

proc wellKnownClientHandler(req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  discard routeArgs
  discard ctx
  var hs = newJObject()
  hs["base_url"] = %"https://localhost:8448"
  var payload = newJObject()
  payload["m.homeserver"] = hs
  successResponse(spec.name, spec.kind, payload)

proc localUserCountHandler(req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  discard routeArgs
  discard ctx
  var payload = newJObject()
  payload["count"] = %0
  successResponse(spec.name, spec.kind, payload)

proc genericImplementedHandler(req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  successResponse(spec.name, spec.kind, asJsonRouteSummary(spec, routeArgs, ctx))

proc defaultHandlerRegistry*(): ApiHandlerRegistry =
  result = initTable[string, ApiRouteHandler]()
  result["get_supported_versions_route"] = versionsHandler
  result["get_login_types_route"] = loginTypesHandler
  result["whoami_route"] = whoamiHandler
  result["get_server_version_route"] = serverVersionHandler
  result["/_tuwunel/server_version"] = serverVersionHandler
  result["/.well-known/matrix/server"] = wellKnownServerHandler
  result["/client/server.json"] = wellKnownClientHandler
  result["/_tuwunel/local_user_count"] = localUserCountHandler

proc routeErrorToResponse(routeName: string; routeKind: RouteKind; err: RouteError): ApiResponse =
  matrixErrorResponse(err.status, err.errcode, err.error, routeName, routeKind)

proc dispatchApiRequest*(
    req: ApiRequest; handlers = defaultHandlerRegistry()): ApiResponse =
  let routeName = req.effectiveRouteName()
  let matches = lookupRoutes(routeName)
  if matches.len == 0:
    return matrixErrorResponse(404, "M_UNRECOGNIZED", "Unrecognized route: " & routeName, routeName, rkUnknown)

  let ctx = buildAuthContext(req)
  let spec = selectRouteSpec(
    matches,
    accessTokenPresent = ctx.accessTokenPresent or ctx.appserviceAuthenticated,
    federationAuthenticated = ctx.federationAuthenticated,
  )
  let decision = checkRouteAuthorization(spec, ctx)
  if not decision.allowed:
    return matrixErrorResponse(401, "M_UNAUTHORIZED", decision.reason, spec.name, spec.kind)

  let runtimeResult = dispatchRoute(
    spec.name,
    accessTokenPresent = ctx.accessTokenPresent or ctx.appserviceAuthenticated,
    federationAuthenticated = ctx.federationAuthenticated,
  )
  if not runtimeResult.ok:
    return routeErrorToResponse(runtimeResult.routeName, runtimeResult.routeKind, runtimeResult.error)

  let routeArgs = extractRouteArgs(req)
  if spec.name in handlers:
    return handlers[spec.name](req, spec, routeArgs, ctx)
  genericImplementedHandler(req, spec, routeArgs, ctx)

import std/[options, strutils, tables]

const
  RustPath* = "router/request.rs"
  RustCrate* = "router"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  RouterRequest* = object
    httpMethod*: string
    path*: string
    routeName*: string
    headers*: Table[string, string]
    accessToken*: Option[string]
    federationAuth*: Option[string]

proc normalizeHeaderName(name: string): string =
  name.strip().toLowerAscii()

proc initRouterRequest*(
    httpMethod, path: string; routeName = ""; accessToken = none(string); federationAuth = none(string)): RouterRequest =
  RouterRequest(
    httpMethod: httpMethod.toUpperAscii(),
    path: path,
    routeName: routeName,
    headers: initTable[string, string](),
    accessToken: accessToken,
    federationAuth: federationAuth,
  )

proc setHeader*(req: var RouterRequest; name, value: string) =
  let normalized = normalizeHeaderName(name)
  if normalized.len == 0:
    return
  req.headers[normalized] = value

proc getHeader*(req: RouterRequest; name: string): Option[string] =
  let normalized = normalizeHeaderName(name)
  if normalized in req.headers:
    return some(req.headers[normalized])
  none(string)

proc hasAccessToken*(req: RouterRequest): bool =
  req.accessToken.isSome and req.accessToken.get.len > 0

proc hasFederationAuth*(req: RouterRequest): bool =
  req.federationAuth.isSome and req.federationAuth.get.len > 0

proc withAccessToken*(req: RouterRequest; token: string): RouterRequest =
  result = req
  if token.len > 0:
    result.accessToken = some(token)
    result.headers["authorization"] = "Bearer " & token

proc withFederationAuth*(req: RouterRequest; value: string): RouterRequest =
  result = req
  if value.len > 0:
    result.federationAuth = some(value)
    result.headers["x-matrix-origin"] = value

proc effectiveRouteName*(req: RouterRequest): string =
  if req.routeName.len > 0:
    return req.routeName
  req.path

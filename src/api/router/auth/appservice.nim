import std/options
import api/router/request

const
  RustPath* = "api/router/auth/appservice.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  AppserviceAuthResult* = object
    authenticated*: bool
    reason*: string

proc configuredToken(req: ApiRequest): Option[string] =
  if req.appserviceToken.isSome and req.appserviceToken.get.len > 0:
    return req.appserviceToken
  none(string)

proc headerToken(req: ApiRequest): Option[string] =
  req.getHeader("x-appservice-token")

proc queryToken(req: ApiRequest): Option[string] =
  req.getQueryParam("access_token")

proc resolveAppserviceToken*(req: ApiRequest): string =
  let explicitToken = configuredToken(req)
  if explicitToken.isSome:
    return explicitToken.get
  let header = headerToken(req)
  if header.isSome and header.get.len > 0:
    return header.get
  let query = queryToken(req)
  if query.isSome and query.get.len > 0:
    return query.get
  ""

proc isAppserviceAuthenticated*(req: ApiRequest): bool =
  resolveAppserviceToken(req).len > 0

proc evaluateAppserviceAuth*(req: ApiRequest): AppserviceAuthResult =
  if isAppserviceAuthenticated(req):
    return AppserviceAuthResult(authenticated: true, reason: "")
  AppserviceAuthResult(authenticated: false, reason: "missing appservice token")

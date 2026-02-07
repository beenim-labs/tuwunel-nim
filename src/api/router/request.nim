import std/[options, strutils, tables]

const
  RustPath* = "api/router/request.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  ApiRequest* = object
    httpMethod*: string
    path*: string
    routeName*: string
    query*: Table[string, string]
    headers*: Table[string, string]
    body*: string
    accessToken*: Option[string]
    federationOrigin*: Option[string]
    appserviceToken*: Option[string]
    uiaaSession*: Option[string]

proc normalizeHeaderName(name: string): string =
  name.strip().toLowerAscii()

proc splitPathAndQuery(rawPath: string): tuple[pathOnly: string, queryRaw: string] =
  let q = rawPath.find('?')
  if q < 0:
    return (rawPath, "")
  (rawPath[0 ..< q], rawPath[q + 1 .. ^1])

proc decodePercent(input: string): string =
  result = newStringOfCap(input.len)
  var i = 0
  while i < input.len:
    if input[i] == '%' and i + 2 < input.len:
      let hex = input[i + 1 .. i + 2]
      try:
        result.add(char(parseHexInt(hex)))
        i += 3
        continue
      except ValueError:
        discard
    if input[i] == '+':
      result.add(' ')
    else:
      result.add(input[i])
    inc i

proc parseQuery(rawQuery: string): Table[string, string] =
  result = initTable[string, string]()
  if rawQuery.len == 0:
    return
  for item in rawQuery.split('&'):
    if item.len == 0:
      continue
    let eq = item.find('=')
    if eq < 0:
      result[decodePercent(item)] = ""
    else:
      let key = decodePercent(item[0 ..< eq])
      let value = decodePercent(item[eq + 1 .. ^1])
      result[key] = value

proc initApiRequest*(
    httpMethod, path: string; routeName = ""; body = ""; accessToken = none(string);
    federationOrigin = none(string); appserviceToken = none(string); uiaaSession = none(string)): ApiRequest =
  let parts = splitPathAndQuery(path)
  ApiRequest(
    httpMethod: httpMethod.toUpperAscii(),
    path: parts.pathOnly,
    routeName: routeName,
    query: parseQuery(parts.queryRaw),
    headers: initTable[string, string](),
    body: body,
    accessToken: accessToken,
    federationOrigin: federationOrigin,
    appserviceToken: appserviceToken,
    uiaaSession: uiaaSession,
  )

proc setHeader*(req: var ApiRequest; name, value: string) =
  let normalized = normalizeHeaderName(name)
  if normalized.len == 0:
    return
  req.headers[normalized] = value

proc getHeader*(req: ApiRequest; name: string): Option[string] =
  let normalized = normalizeHeaderName(name)
  if normalized in req.headers:
    return some(req.headers[normalized])
  none(string)

proc setQueryParam*(req: var ApiRequest; key, value: string) =
  if key.len == 0:
    return
  req.query[key] = value

proc getQueryParam*(req: ApiRequest; key: string): Option[string] =
  if key in req.query:
    return some(req.query[key])
  none(string)

proc hasAccessToken*(req: ApiRequest): bool =
  req.accessToken.isSome and req.accessToken.get.len > 0

proc hasFederationOrigin*(req: ApiRequest): bool =
  req.federationOrigin.isSome and req.federationOrigin.get.len > 0

proc hasAppserviceToken*(req: ApiRequest): bool =
  req.appserviceToken.isSome and req.appserviceToken.get.len > 0

proc hasUiaaSession*(req: ApiRequest): bool =
  req.uiaaSession.isSome and req.uiaaSession.get.len > 0

proc withAccessToken*(req: ApiRequest; token: string): ApiRequest =
  result = req
  if token.len > 0:
    result.accessToken = some(token)
    result.headers["authorization"] = "Bearer " & token

proc withFederationOrigin*(req: ApiRequest; origin: string): ApiRequest =
  result = req
  if origin.len > 0:
    result.federationOrigin = some(origin)
    result.headers["x-matrix-origin"] = origin

proc withAppserviceToken*(req: ApiRequest; token: string): ApiRequest =
  result = req
  if token.len > 0:
    result.appserviceToken = some(token)

proc withUiaaSession*(req: ApiRequest; session: string): ApiRequest =
  result = req
  if session.len > 0:
    result.uiaaSession = some(session)

proc effectiveRouteName*(req: ApiRequest): string =
  if req.routeName.len > 0:
    return req.routeName
  req.path

const
  RustPath* = "service/federation/execute.rs"
  RustCrate* = "service"

import std/[httpcore, json, strutils, tables, uri]

type
  ActualDest* = object
    host*: string
    baseUrl*: string

  FederationRequest* = object
    httpMethod*: string
    path*: string
    body*: JsonNode

  PreparedFederationRequest* = object
    dest*: string
    actual*: ActualDest
    httpMethod*: string
    url*: string
    headers*: Table[string, string]
    body*: JsonNode

  FederationConfig* = object
    allowFederation*: bool
    forbiddenServers*: seq[string]
    localServerName*: string

  FederationService* = object
    config*: FederationConfig
    actualDestinations*: Table[string, ActualDest]
    invalidatedDestinations*: seq[string]
    invalidatedOverrides*: seq[string]

  FederationResult* = tuple[ok: bool, message: string]

proc initFederationConfig*(
  localServerName: string;
  allowFederation = true;
  forbiddenServers: openArray[string] = [];
): FederationConfig =
  FederationConfig(
    allowFederation: allowFederation,
    forbiddenServers: @forbiddenServers,
    localServerName: localServerName,
  )

proc initFederationService*(config: FederationConfig): FederationService =
  FederationService(
    config: config,
    actualDestinations: initTable[string, ActualDest](),
    invalidatedDestinations: @[],
    invalidatedOverrides: @[],
  )

proc actualDest*(host: string; baseUrl = ""): ActualDest =
  ActualDest(
    host: host,
    baseUrl: if baseUrl.len > 0: baseUrl else: "https://" & host,
  )

proc federationRequest*(path: string; httpMethod = "GET"; body: JsonNode = newJObject()): FederationRequest =
  FederationRequest(httpMethod: httpMethod, path: path, body: if body.isNil: newJObject() else: body.copy())

proc executePolicy*(service: FederationService; dest: string): FederationResult =
  if not service.config.allowFederation:
    return (false, "Federation is disabled.")
  if dest in service.config.forbiddenServers:
    return (false, "Federation with " & dest & " is not allowed.")
  (true, "")

proc resolveActual*(service: FederationService; dest: string): ActualDest =
  service.actualDestinations.getOrDefault(dest, actualDest(dest))

proc joinUrl(baseUrl, path: string): string =
  let base = baseUrl.strip(trailing = true, chars = {'/'})
  if path.startsWith("/"):
    base & path
  else:
    base & "/" & path

proc isBlockedIpLiteral*(host: string): bool =
  host == "127.0.0.1" or host == "::1" or
    host.startsWith("10.") or host.startsWith("192.168.") or
    host.startsWith("172.16.") or host.startsWith("172.17.") or
    host.startsWith("172.18.") or host.startsWith("172.19.") or
    host.startsWith("172.2") or host.startsWith("172.30.") or host.startsWith("172.31.")

proc validateUrl*(url: string): FederationResult =
  let parsed = parseUri(url)
  if parsed.hostname.len > 0 and isBlockedIpLiteral(parsed.hostname):
    return (false, "request URL host is denied by federation IP policy")
  (true, "")

proc toHttpRequest*(
  service: FederationService;
  actual: ActualDest;
  dest: string;
  request: FederationRequest;
): PreparedFederationRequest =
  var headers = initTable[string, string]()
  headers["Authorization"] =
    "X-Matrix origin=" & service.config.localServerName & ",destination=" & dest
  headers["Content-Type"] = "application/json"

  PreparedFederationRequest(
    dest: dest,
    actual: actual,
    httpMethod: request.httpMethod,
    url: joinUrl(actual.baseUrl, request.path),
    headers: headers,
    body: if request.body.isNil: newJObject() else: request.body.copy(),
  )

proc prepare*(
  service: FederationService;
  dest: string;
  request: FederationRequest;
): tuple[ok: bool, prepared: PreparedFederationRequest, message: string] =
  let policy = service.executePolicy(dest)
  if not policy.ok:
    return (false, PreparedFederationRequest(), policy.message)
  let actual = service.resolveActual(dest)
  let prepared = service.toHttpRequest(actual, dest, request)
  let urlPolicy = validateUrl(prepared.url)
  if not urlPolicy.ok:
    return (false, PreparedFederationRequest(), urlPolicy.message)
  (true, prepared, "")

proc responsePolicy*(status: HttpCode; incomingResponseValid = true): FederationResult =
  if ord(status) < 200 or ord(status) >= 300:
    return (false, "federation server returned unsuccessful HTTP response")
  if not incomingResponseValid:
    return (false, "Server returned bad 200 response")
  (true, "")

proc handleError*(
  service: var FederationService;
  dest: string;
  actual: ActualDest;
  httpMethod, url, errorKind: string;
): FederationResult =
  discard httpMethod
  discard url
  discard actual
  discard errorKind
  service.invalidatedDestinations.add(dest)
  service.invalidatedOverrides.add(dest)
  (false, "federation request failed")

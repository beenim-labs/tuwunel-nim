import std/[strutils, tables]
import api/router/request

const
  RustPath* = "api/router/args.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  RouteArgs* = object
    routeName*: string
    pathSegments*: seq[string]
    queryParams*: Table[string, string]
    pathParams*: Table[string, string]

proc normalizePath(path: string): string =
  result = path.strip()
  if result.len == 0:
    return "/"
  if not result.startsWith("/"):
    result = "/" & result

proc pathSegments(path: string): seq[string] =
  result = @[]
  for segment in normalizePath(path).split('/'):
    if segment.len > 0:
      result.add(segment)

proc maybeRoutePathParams(routeName: string; segments: openArray[string]): Table[string, string] =
  result = initTable[string, string]()
  if routeName.contains("{room_id}") and segments.len > 0:
    result["room_id"] = segments[^1]
  if routeName.contains("{event_type}") and segments.len > 0:
    result["event_type"] = segments[^1]
  if routeName.contains("{event_id}") and segments.len > 0:
    result["event_id"] = segments[^1]
  if routeName.contains("{user_id}") and segments.len > 0:
    result["user_id"] = segments[^1]

proc extractRouteArgs*(req: ApiRequest): RouteArgs =
  let segments = pathSegments(req.path)
  result = RouteArgs(
    routeName: req.effectiveRouteName(),
    pathSegments: segments,
    queryParams: req.query,
    pathParams: maybeRoutePathParams(req.effectiveRouteName(), segments),
  )

proc hasQueryParam*(args: RouteArgs; key: string): bool =
  key in args.queryParams

proc hasPathParam*(args: RouteArgs; key: string): bool =
  key in args.pathParams

proc queryParamOr*(args: RouteArgs; key, fallback: string): string =
  if key in args.queryParams:
    return args.queryParams[key]
  fallback

proc pathParamOr*(args: RouteArgs; key, fallback: string): string =
  if key in args.pathParams:
    return args.pathParams[key]
  fallback

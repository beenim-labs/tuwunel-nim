import std/[json, strutils, tables]
import api/generated_route_runtime

const
  RustPath* = "api/router/response.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  ApiResponse* = object
    routeName*: string
    routeKind*: RouteKind
    status*: int
    ok*: bool
    headers*: Table[string, string]
    body*: JsonNode
    errcode*: string
    error*: string

proc defaultHeaders(): Table[string, string] =
  result = initTable[string, string]()
  result["content-type"] = "application/json"

proc initApiResponse*(
    status: int; routeName = ""; routeKind = rkUnknown; ok = false; body = newJObject()): ApiResponse =
  ApiResponse(
    routeName: routeName,
    routeKind: routeKind,
    status: status,
    ok: ok,
    headers: defaultHeaders(),
    body: body,
    errcode: "",
    error: "",
  )

proc matrixErrorResponse*(
    status: int; errcode, message: string; routeName = ""; routeKind = rkUnknown): ApiResponse =
  var node = newJObject()
  node["errcode"] = %errcode
  node["error"] = %message
  result = initApiResponse(status, routeName, routeKind, ok = false, body = node)
  result.errcode = errcode
  result.error = message

proc successResponse*(
    routeName: string; routeKind = rkUnknown; payload: JsonNode = newJObject()): ApiResponse =
  var body = payload
  if body.kind == JNull:
    body = newJObject()
  initApiResponse(200, routeName, routeKind, ok = true, body = body)

proc withHeader*(resp: ApiResponse; key, value: string): ApiResponse =
  result = resp
  let normalized = key.strip().toLowerAscii()
  if normalized.len > 0:
    result.headers[normalized] = value

proc compactBody*(resp: ApiResponse): string =
  $resp.body

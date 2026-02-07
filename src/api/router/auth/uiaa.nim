import std/[options, strutils]
import api/router/request

const
  RustPath* = "api/router/auth/uiaa.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  UiaaAuthResult* = object
    completed*: bool
    reason*: string

proc sessionFromBody(body: string): string =
  let key = "\"session\""
  let i = body.find(key)
  if i < 0:
    return ""
  let startQuote = body.find('"', i + key.len)
  if startQuote < 0:
    return ""
  let endQuote = body.find('"', startQuote + 1)
  if endQuote <= startQuote:
    return ""
  body[startQuote + 1 ..< endQuote]

proc sessionFromHeader(req: ApiRequest): Option[string] =
  req.getHeader("x-uiaa-session")

proc resolveUiaaSession*(req: ApiRequest): string =
  if req.uiaaSession.isSome and req.uiaaSession.get.len > 0:
    return req.uiaaSession.get
  let header = sessionFromHeader(req)
  if header.isSome and header.get.len > 0:
    return header.get
  sessionFromBody(req.body).strip()

proc hasUiaaCompletion*(req: ApiRequest): bool =
  resolveUiaaSession(req).len > 0

proc evaluateUiaa*(req: ApiRequest): UiaaAuthResult =
  if hasUiaaCompletion(req):
    return UiaaAuthResult(completed: true, reason: "")
  UiaaAuthResult(completed: false, reason: "uiaa session missing")

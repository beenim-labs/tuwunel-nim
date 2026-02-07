import std/[options, strutils]
import api/router/request

const
  RustPath* = "api/router/auth/server.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  ServerAuthResult* = object
    authenticated*: bool
    reason*: string

proc headerOrigin(req: ApiRequest): Option[string] =
  req.getHeader("x-matrix-origin")

proc tokenOrigin(req: ApiRequest): Option[string] =
  if req.federationOrigin.isSome:
    return req.federationOrigin
  none(string)

proc normalizeOrigin(raw: string): string =
  raw.strip(chars = {' ', '\t', '"', '\''})

proc resolveFederationOrigin*(req: ApiRequest): string =
  let token = tokenOrigin(req)
  if token.isSome and token.get.len > 0:
    return normalizeOrigin(token.get)
  let header = headerOrigin(req)
  if header.isSome and header.get.len > 0:
    return normalizeOrigin(header.get)
  ""

proc isFederationAuthenticated*(req: ApiRequest): bool =
  resolveFederationOrigin(req).len > 0

proc evaluateServerAuth*(req: ApiRequest): ServerAuthResult =
  if isFederationAuthenticated(req):
    return ServerAuthResult(authenticated: true, reason: "")
  ServerAuthResult(authenticated: false, reason: "missing federation origin")

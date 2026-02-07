import std/[options, strutils]
import api/generated_route_runtime
import request

const
  RustPath* = "router/layers.rs"
  RustCrate* = "router"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  RouterLayer* = enum
    rlRequestNormalize
    rlClientAuth
    rlFederationAuth
    rlErrorShape

  RouterLayerReport* = object
    routeName*: string
    allowed*: bool
    requiresAuth*: bool
    federationOnly*: bool
    authSatisfied*: bool
    appliedLayers*: seq[RouterLayer]
    denialReason*: string

proc defaultRouterLayers*(): seq[RouterLayer] =
  @[
    rlRequestNormalize,
    rlClientAuth,
    rlFederationAuth,
    rlErrorShape,
  ]

proc applyRouterLayers*(req: RouterRequest): RouterLayerReport =
  let routeName = req.effectiveRouteName()
  result = RouterLayerReport(
    routeName: routeName,
    allowed: true,
    requiresAuth: false,
    federationOnly: false,
    authSatisfied: true,
    appliedLayers: @[],
    denialReason: "",
  )

  let specOpt = lookupRoute(routeName)
  if specOpt.isNone:
    result.allowed = false
    result.authSatisfied = false
    result.denialReason = "unrecognized route"
    return

  let spec = specOpt.get
  result.requiresAuth = spec.requiresAuth
  result.federationOnly = spec.federationOnly
  result.appliedLayers = defaultRouterLayers()

  let accessTokenPresent = req.hasAccessToken()
  let federationAuthenticated = req.hasFederationAuth()
  let authorized = authorizationState(spec, accessTokenPresent, federationAuthenticated)
  result.authSatisfied = authorized
  result.allowed = authorized

  if not authorized:
    if spec.federationOnly:
      result.denialReason = "missing federation authentication"
    elif spec.requiresAuth:
      result.denialReason = "missing access token authentication"
    else:
      result.denialReason = "authorization failure"

proc layerSummary*(report: RouterLayerReport): string =
  var parts: seq[string] = @[]
  parts.add("route=" & report.routeName)
  parts.add("allowed=" & $report.allowed)
  parts.add("requires_auth=" & $report.requiresAuth)
  parts.add("federation_only=" & $report.federationOnly)
  if report.denialReason.len > 0:
    parts.add("reason=" & report.denialReason)
  parts.join(" ")

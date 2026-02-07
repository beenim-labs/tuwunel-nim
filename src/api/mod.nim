import generated_route_inventory
import generated_route_types
import generated_route_runtime

type
  ApiSurfaceSummary* = object
    totalRoutes*: int
    clientRoutes*: int
    serverRoutes*: int
    manualRoutes*: int
    publicClientRoutes*: int

proc buildApiSurfaceSummary*(): ApiSurfaceSummary =
  ApiSurfaceSummary(
    totalRoutes: TotalRouteCount,
    clientRoutes: ClientRumaRouteCount,
    serverRoutes: ServerRumaRouteCount,
    manualRoutes: ManualRouteCount,
    publicClientRoutes: PublicClientRouteNames.len,
  )

proc dispatchApiRoute*(
    routeName: string; accessTokenPresent = false; federationAuthenticated = false): RouteDispatchResult =
  dispatchRoute(routeName, accessTokenPresent, federationAuthenticated)

proc apiSurfaceSummaryLine*(summary: ApiSurfaceSummary): string =
  "total=" & $summary.totalRoutes &
    " client=" & $summary.clientRoutes &
    " server=" & $summary.serverRoutes &
    " manual=" & $summary.manualRoutes &
    " public_client=" & $summary.publicClientRoutes

export generated_route_inventory
export generated_route_types
export generated_route_runtime

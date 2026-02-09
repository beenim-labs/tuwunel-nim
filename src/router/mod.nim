import api/generated_route_inventory
import api/generated_route_runtime

type
  RouterStatus* = object
    routesLoaded*: int
    clientRoutesLoaded*: int
    serverRoutesLoaded*: int
    manualRoutesLoaded*: int
    authRequiredRoutes*: int
    federationRoutes*: int

proc buildRouterStatus*(): RouterStatus =
  var authRequired = 0
  var federation = 0
  for spec in RouteSpecs:
    if spec.requiresAuth:
      inc authRequired
    if spec.federationOnly:
      inc federation

  RouterStatus(
    routesLoaded: TotalRouteCount,
    clientRoutesLoaded: ClientRumaRouteCount,
    serverRoutesLoaded: ServerRumaRouteCount,
    manualRoutesLoaded: ManualRouteCount,
    authRequiredRoutes: authRequired,
    federationRoutes: federation,
  )

proc defaultRouterStatus*(): RouterStatus =
  buildRouterStatus()

proc dispatchCompatibilityRoute*(
    routeName: string;
    accessTokenPresent = false;
    federationAuthenticated = false): RouteDispatchResult =
  dispatchRoute(routeName, accessTokenPresent, federationAuthenticated)

proc routerRegistry*(): RouteRegistry =
  routeRegistry()

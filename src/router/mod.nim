type
  RouterStatus* = object
    routesLoaded*: int

proc defaultRouterStatus*(): RouterStatus =
  RouterStatus(routesLoaded: 0)

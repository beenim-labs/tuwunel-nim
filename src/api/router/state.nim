import std/tables
import api/router/response

const
  RustPath* = "api/router/state.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  ApiRouterState* = ref object
    totalRequests*: int
    okResponses*: int
    deniedResponses*: int
    statusCounts*: Table[int, int]
    lastRoute*: string
    lastStatus*: int

proc initApiRouterState*(): ApiRouterState =
  new(result)
  result.totalRequests = 0
  result.okResponses = 0
  result.deniedResponses = 0
  result.statusCounts = initTable[int, int]()
  result.lastRoute = ""
  result.lastStatus = 0

proc record*(state: ApiRouterState; resp: ApiResponse) =
  inc state.totalRequests
  if resp.ok:
    inc state.okResponses
  else:
    inc state.deniedResponses
  state.statusCounts[resp.status] = state.statusCounts.getOrDefault(resp.status, 0) + 1
  state.lastRoute = resp.routeName
  state.lastStatus = resp.status

proc statusHits*(state: ApiRouterState; status: int): int =
  state.statusCounts.getOrDefault(status, 0)

import ../run
import ../request
import ../router

const
  RustPath* = "router/serve/unix.rs"
  RustCrate* = "router"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  UnixServeConfig* = object
    socketPath*: string
    permissions*: string
    owner*: string

proc defaultUnixServeConfig*(): UnixServeConfig =
  UnixServeConfig(
    socketPath: "",
    permissions: "660",
    owner: "",
  )

proc unixConfigValid*(config: UnixServeConfig): bool =
  config.socketPath.len > 0

proc runUnixServeBatch*(
    requests: openArray[RouterRequest]; config = defaultUnixServeConfig()): RouterRunReport =
  discard config
  var engine = initRouterEngine()
  runRouterRequests(engine, requests)

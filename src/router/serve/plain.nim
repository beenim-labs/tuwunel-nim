import ../run
import ../request
import ../router

const
  RustPath* = "router/serve/plain.rs"
  RustCrate* = "router"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  PlainServeConfig* = object
    bindAddress*: string
    maxRequestSizeBytes*: int
    keepAliveSeconds*: int

proc defaultPlainServeConfig*(): PlainServeConfig =
  PlainServeConfig(
    bindAddress: "127.0.0.1:8008",
    maxRequestSizeBytes: 20 * 1024 * 1024,
    keepAliveSeconds: 60,
  )

proc plainConfigValid*(config: PlainServeConfig): bool =
  config.bindAddress.len > 0 and config.maxRequestSizeBytes > 0 and config.keepAliveSeconds > 0

proc withBindAddress*(config: PlainServeConfig; address: string): PlainServeConfig =
  result = config
  if address.len > 0:
    result.bindAddress = address

proc withRequestSize*(config: PlainServeConfig; bytes: int): PlainServeConfig =
  result = config
  if bytes > 0:
    result.maxRequestSizeBytes = bytes

proc keepAliveMillis*(config: PlainServeConfig): int =
  max(0, config.keepAliveSeconds) * 1000

proc plainServeSummary*(config: PlainServeConfig): string =
  "plain(bind=" & config.bindAddress & ", max_bytes=" & $config.maxRequestSizeBytes &
    ", keepalive_s=" & $config.keepAliveSeconds & ")"

proc runPlainServeBatch*(
    requests: openArray[RouterRequest]; config = defaultPlainServeConfig()): RouterRunReport =
  discard config
  var engine = initRouterEngine()
  runRouterRequests(engine, requests)

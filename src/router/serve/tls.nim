import ../run
import ../request
import ../router

const
  RustPath* = "router/serve/tls.rs"
  RustCrate* = "router"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  TlsServeConfig* = object
    bindAddress*: string
    certPath*: string
    keyPath*: string
    dualProtocol*: bool

proc defaultTlsServeConfig*(): TlsServeConfig =
  TlsServeConfig(
    bindAddress: "0.0.0.0:8448",
    certPath: "",
    keyPath: "",
    dualProtocol: false,
  )

proc tlsConfigValid*(config: TlsServeConfig): bool =
  (config.certPath.len > 0 and config.keyPath.len > 0) or config.dualProtocol

proc runTlsServeBatch*(
    requests: openArray[RouterRequest]; config = defaultTlsServeConfig()): RouterRunReport =
  discard config
  var engine = initRouterEngine()
  runRouterRequests(engine, requests)

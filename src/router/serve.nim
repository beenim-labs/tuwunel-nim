import router/serve/plain
import router/serve/tls
import router/serve/unix
import router/run
import router/request

const
  RustPath* = "router/serve/mod.rs"
  RustCrate* = "router"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  RouterServeMode* = enum
    rsmPlain
    rsmTls
    rsmUnix

  RouterServeConfig* = object
    mode*: RouterServeMode
    plain*: PlainServeConfig
    tls*: TlsServeConfig
    unix*: UnixServeConfig

proc defaultRouterServeConfig*(): RouterServeConfig =
  RouterServeConfig(
    mode: rsmPlain,
    plain: defaultPlainServeConfig(),
    tls: defaultTlsServeConfig(),
    unix: defaultUnixServeConfig(),
  )

proc runServeBatch*(
    requests: openArray[RouterRequest]; config = defaultRouterServeConfig()): RouterRunReport =
  case config.mode
  of rsmPlain:
    runPlainServeBatch(requests, config.plain)
  of rsmTls:
    runTlsServeBatch(requests, config.tls)
  of rsmUnix:
    runUnixServeBatch(requests, config.unix)

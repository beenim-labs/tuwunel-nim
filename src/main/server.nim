import std/strutils
import core/config_values

const
  RustPath* = "main/server.rs"
  RustCrate* = "main"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  ServerConfig* = object
    listening*: bool
    bindAddress*: string
    unixSocketPath*: string
    tlsEnabled*: bool

  ServerHandle* = object
    config*: ServerConfig
    started*: bool
    stopReason*: string

proc valueAsBool(value: ConfigValue; fallback: bool): bool =
  case value.kind
  of cvBool:
    value.b
  of cvInt:
    value.i != 0
  of cvString:
    value.s.toLowerAscii() in ["1", "true", "yes", "on"]
  else:
    fallback

proc valueAsString(value: ConfigValue; fallback: string): string =
  case value.kind
  of cvString:
    value.s
  of cvInt:
    $value.i
  of cvFloat:
    $value.f
  else:
    fallback

proc readBool(values: FlatConfig; key: string; fallback: bool): bool =
  if key in values:
    return valueAsBool(values[key], fallback)
  fallback

proc readString(values: FlatConfig; key, fallback: string): string =
  if key in values:
    return valueAsString(values[key], fallback)
  fallback

proc loadServerConfig*(values: FlatConfig): ServerConfig =
  ServerConfig(
    listening: readBool(values, "listening", true),
    bindAddress: readString(values, "address", "127.0.0.1:8008"),
    unixSocketPath: readString(values, "unix_socket_path", ""),
    tlsEnabled: readBool(values, "tls.dual_protocol", false),
  )

proc initServerHandle*(config: ServerConfig): ServerHandle =
  ServerHandle(config: config, started: false, stopReason: "")

proc startServer*(server: var ServerHandle): tuple[ok: bool, err: string] =
  if not server.config.listening:
    return (true, "")

  if server.config.bindAddress.len == 0 and server.config.unixSocketPath.len == 0:
    return (false, "Server listening enabled but no bind address or unix socket configured")

  server.started = true
  (true, "")

proc stopServer*(server: var ServerHandle; reason = "shutdown"): bool =
  if not server.started:
    server.stopReason = reason
    return true

  server.started = false
  server.stopReason = reason
  true

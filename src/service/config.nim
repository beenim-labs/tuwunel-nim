import std/strutils
import core/config_values

const
  RustPath* = "service/config/mod.rs"
  RustCrate* = "service"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  ServiceRuntimeConfig* = object
    serverName*: string
    databasePath*: string
    readOnly*: bool
    secondary*: bool
    repair*: bool
    neverDropColumns*: bool
    listening*: bool
    startupNetburst*: bool
    adminExecute*: seq[string]

proc valueAsString(value: ConfigValue; fallback: string): string =
  case value.kind
  of cvString:
    value.s
  of cvInt:
    $value.i
  of cvFloat:
    $value.f
  of cvBool:
    if value.b: "true" else: "false"
  of cvNull:
    fallback
  of cvArray:
    if value.items.len == 0:
      fallback
    else:
      $value.items[0]

proc valueAsBool(value: ConfigValue; fallback: bool): bool =
  case value.kind
  of cvBool:
    value.b
  of cvInt:
    value.i != 0
  of cvFloat:
    value.f != 0.0
  of cvString:
    let lower = value.s.toLowerAscii()
    lower in ["1", "true", "yes", "on"]
  else:
    fallback

proc valueAsStringSeq(value: ConfigValue): seq[string] =
  result = @[]
  case value.kind
  of cvArray:
    for item in value.items:
      result.add(valueAsString(item, ""))
  of cvString:
    result.add(value.s)
  else:
    discard

proc readString(values: FlatConfig; key, fallback: string): string =
  if key in values:
    return valueAsString(values[key], fallback)
  fallback

proc readBool(values: FlatConfig; key: string; fallback: bool): bool =
  if key in values:
    return valueAsBool(values[key], fallback)
  fallback

proc readStringSeq(values: FlatConfig; key: string): seq[string] =
  if key in values:
    return valueAsStringSeq(values[key])
  @[]

proc loadServiceRuntimeConfig*(values: FlatConfig): ServiceRuntimeConfig =
  ServiceRuntimeConfig(
    serverName: readString(values, "server_name", ""),
    databasePath: readString(values, "database_path", "data"),
    readOnly: readBool(values, "rocksdb_read_only", false),
    secondary: readBool(values, "rocksdb_secondary", false),
    repair: readBool(values, "rocksdb_repair", false),
    neverDropColumns: readBool(values, "rocksdb_never_drop_columns", false),
    listening: readBool(values, "listening", true),
    startupNetburst: readBool(values, "startup_netburst", true),
    adminExecute: readStringSeq(values, "admin_execute"),
  )

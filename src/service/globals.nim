import std/[strutils, times]
import service/globals/data

const
  RustPath* = "service/globals/mod.rs"
  RustCrate* = "service"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  RuntimeGlobals* = object
    startedAtUnix*: int64
    instanceId*: string
    serverName*: string
    store*: GlobalDataStore

proc initRuntimeGlobals*(serverName: string; instanceId = ""): RuntimeGlobals =
  let nowUnix = int64(getTime().toUnix())
  var normalizedId = instanceId.strip()
  if normalizedId.len == 0:
    normalizedId = "tuwunel-nim-" & $nowUnix

  result = RuntimeGlobals(
    startedAtUnix: nowUnix,
    instanceId: normalizedId,
    serverName: serverName,
    store: newGlobalDataStore(),
  )

  result.store.setValue("instance_id", normalizedId)
  result.store.setValue("server_name", serverName)
  result.store.setValue("started_at_unix", $nowUnix)

proc uptimeSeconds*(globals: RuntimeGlobals; nowUnix = int64(getTime().toUnix())): int64 =
  if nowUnix < globals.startedAtUnix:
    return 0
  nowUnix - globals.startedAtUnix

proc setHealth*(globals: RuntimeGlobals; status: string) =
  globals.store.setValue("health", status)

proc health*(globals: RuntimeGlobals): string =
  globals.store.getValue("health")

proc touchLifecycle*(globals: RuntimeGlobals; phase: string) =
  let key = "lifecycle." & phase.strip().toLowerAscii()
  discard globals.store.addCounter(key, 1)

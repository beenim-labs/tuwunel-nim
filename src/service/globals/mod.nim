import service/globals

const
  RustPath* = "service/globals/mod.rs"
  RustCrate* = "service"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  GlobalsSnapshot* = object
    serverName*: string
    instanceId*: string
    health*: string
    uptimeSeconds*: int64
    valueCount*: int

proc snapshotGlobals*(g: RuntimeGlobals): GlobalsSnapshot =
  GlobalsSnapshot(
    serverName: g.serverName,
    instanceId: g.instanceId,
    health: g.health(),
    uptimeSeconds: g.uptimeSeconds(),
    valueCount: g.store.valueCount(),
  )

proc globalsHealthy*(snap: GlobalsSnapshot): bool =
  snap.health == "running" or snap.health == "booting"

proc globalsSummaryLine*(snap: GlobalsSnapshot): string =
  "instance=" & snap.instanceId &
    " server=" & snap.serverName &
    " health=" & snap.health &
    " uptime_s=" & $snap.uptimeSeconds &
    " values=" & $snap.valueCount

export globals

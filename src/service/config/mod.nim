import core/config_values
import service/config

const
  RustPath* = "service/config/mod.rs"
  RustCrate* = "service"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  ServiceConfigSummary* = object
    serverName*: string
    databasePath*: string
    readOnly*: bool
    listening*: bool
    startupNetburst*: bool
    adminExecuteCount*: int

proc summarizeServiceConfig*(cfg: ServiceRuntimeConfig): ServiceConfigSummary =
  ServiceConfigSummary(
    serverName: cfg.serverName,
    databasePath: cfg.databasePath,
    readOnly: cfg.readOnly,
    listening: cfg.listening,
    startupNetburst: cfg.startupNetburst,
    adminExecuteCount: cfg.adminExecute.len,
  )

proc loadServiceConfigSummary*(values: FlatConfig): ServiceConfigSummary =
  summarizeServiceConfig(loadServiceRuntimeConfig(values))

proc serviceConfigReady*(summary: ServiceConfigSummary): bool =
  summary.serverName.len > 0 and summary.databasePath.len > 0

proc serviceConfigSummaryLine*(summary: ServiceConfigSummary): string =
  "server=" & summary.serverName &
    " db=" & summary.databasePath &
    " read_only=" & $summary.readOnly &
    " listening=" & $summary.listening &
    " startup_netburst=" & $summary.startupNetburst &
    " admin_execute=" & $summary.adminExecuteCount

export config

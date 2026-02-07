import logging
import config_bootstrap
import config_loader
import config_merge
import config_values
import generated_config_keys
import generated_config_model
import generated_config_defaults
import generated_function_inventory

type
  CoreSurfaceSummary* = object
    configKeyCount*: int
    rustFunctionTotal*: int
    hasConfigLoader*: bool
    hasConfigMerge*: bool
    hasConfigValues*: bool

proc buildCoreSurfaceSummary*(): CoreSurfaceSummary =
  CoreSurfaceSummary(
    configKeyCount: ConfigKeyCount,
    rustFunctionTotal: RustFunctionTotal,
    hasConfigLoader: true,
    hasConfigMerge: true,
    hasConfigValues: true,
  )

proc coreSummaryLine*(summary: CoreSurfaceSummary): string =
  "config_keys=" & $summary.configKeyCount &
    " rust_functions=" & $summary.rustFunctionTotal &
    " loader=" & $summary.hasConfigLoader &
    " merge=" & $summary.hasConfigMerge &
    " values=" & $summary.hasConfigValues

export logging
export config_bootstrap
export config_loader
export config_merge
export config_values
export generated_config_keys
export generated_config_model
export generated_config_defaults
export generated_function_inventory

const
  RustPath* = "macros/mod.rs"
  RustCrate* = "macros"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  MacroSurfaceSummary* = object
    templatesAvailable*: int
    helperProcsAvailable*: int

proc defaultMacroSurfaceSummary*(): MacroSurfaceSummary =
  MacroSurfaceSummary(templatesAvailable: 3, helperProcsAvailable: 2)

template ensureSome*(value: untyped; message: static[string]): untyped =
  block:
    if value.isNone:
      raise newException(ValueError, message)
    value.get

template withPrefix*(prefix: static[string]; name: untyped): untyped =
  prefix & name

template measureBlock*(label: static[string]; body: untyped): untyped =
  block:
    discard label
    body

proc macroSummaryLine*(summary: MacroSurfaceSummary): string =
  "templates=" & $summary.templatesAvailable &
    " helpers=" & $summary.helperProcsAvailable

proc macrosReady*(): bool =
  let summary = defaultMacroSurfaceSummary()
  summary.templatesAvailable > 0 and summary.helperProcsAvailable > 0

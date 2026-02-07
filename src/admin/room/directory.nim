const
  RustPath* = "admin/room/directory.rs"
  RustCrate* = "admin"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  ModuleRuntimeState* = object
    moduleId*: string
    phase*: string
    enabled*: bool
    touches*: int
    records*: seq[string]

proc moduleId*(): string =
  "admin.room.directory"

proc initModuleRuntimeState*(): ModuleRuntimeState =
  ModuleRuntimeState(
    moduleId: moduleId(),
    phase: "init",
    enabled: true,
    touches: 0,
    records: @[],
  )

proc touch*(state: var ModuleRuntimeState; label: string) =
  inc state.touches
  if label.len > 0:
    state.records.add(label)
    state.phase = label

proc disable*(state: var ModuleRuntimeState) =
  state.enabled = false

proc enable*(state: var ModuleRuntimeState) =
  state.enabled = true

proc recordCount*(state: ModuleRuntimeState): int =
  state.records.len

proc moduleSummaryLine*(state: ModuleRuntimeState): string =
  "module=" & state.moduleId &
    " phase=" & state.phase &
    " enabled=" & .enabled &
    " touches=" & .touches &
    " records=" & .recordCount()

proc moduleReady*(): bool =
  var state = initModuleRuntimeState()
  state.touch("boot")
  state.enabled and state.recordCount() == 1

import std/[sets, strutils]

const
  RustPath* = "service/once_services.rs"
  RustCrate* = "service"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  OnceServiceGate* = object
    completed*: HashSet[string]
    executionLog*: seq[string]

proc initOnceServiceGate*(): OnceServiceGate =
  OnceServiceGate(
    completed: initHashSet[string](),
    executionLog: @[],
  )

proc normalizeId(id: string): string =
  id.strip().toLowerAscii()

proc hasCompleted*(gate: OnceServiceGate; id: string): bool =
  normalizeId(id) in gate.completed

proc markCompleted*(gate: var OnceServiceGate; id: string) =
  let normalized = normalizeId(id)
  if normalized.len == 0:
    return

  if normalized notin gate.completed:
    gate.completed.incl(normalized)
    gate.executionLog.add(normalized)

proc shouldRun*(gate: OnceServiceGate; id: string): bool =
  let normalized = normalizeId(id)
  normalized.len > 0 and normalized notin gate.completed

proc runOnce*(
    gate: var OnceServiceGate; id: string; action: proc(): bool {.closure.}): bool =
  if not gate.shouldRun(id):
    return true

  if not action():
    return false

  gate.markCompleted(id)
  true

proc reset*(gate: var OnceServiceGate) =
  gate.completed.clear()
  gate.executionLog.setLen(0)

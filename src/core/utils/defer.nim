const
  RustPath* = "core/utils/defer.rs"
  RustCrate* = "core"

type DeferGuard* = object
  action: proc() {.closure.}
  active: bool

proc `=destroy`*(guard: var DeferGuard) =
  if guard.active and not guard.action.isNil:
    guard.active = false
    guard.action()

proc newDeferGuard*(action: proc() {.closure.}): DeferGuard =
  DeferGuard(action: action, active: true)

proc dismiss*(guard: var DeferGuard) =
  guard.active = false

proc runNow*(guard: var DeferGuard) =
  if guard.active and not guard.action.isNil:
    guard.active = false
    guard.action()

template scopeRestore*(location: untyped; temporary: untyped; body: untyped): untyped =
  block:
    let previousValue = location
    location = temporary
    var restoreGuard {.inject.} = newDeferGuard(proc() =
      location = previousValue
    )
    body
    discard restoreGuard

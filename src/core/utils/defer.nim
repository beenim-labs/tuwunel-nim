## Defer / scope-guard utilities.
##
## Ported from Rust core/utils/defer.rs — Nim has native `defer` but
## this provides the exchange/restore pattern.

const
  RustPath* = "core/utils/defer.rs"
  RustCrate* = "core"

proc exchange*[T](target: var T; newVal: T): T =
  ## Swap newVal into target, returning the old value.
  ## Useful for scope_restore patterns.
  result = target
  target = newVal

template scopeRestore*(variable: untyped; tempVal: untyped) =
  ## Temporarily replace variable with tempVal, restoring original on scope exit.
  let saved = variable
  variable = tempVal
  defer:
    variable = saved

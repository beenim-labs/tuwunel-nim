## Module macros — compile-time helpers.
##
## Ported from Rust core/mods/macros.rs

const
  RustPath* = "core/mods/macros.rs"
  RustCrate* = "core"

## In Rust, this provides proc-macro definitions for module registration.
## In Nim, we use templates and pragmas instead.

template registerModule*(name: string; body: untyped) =
  ## Register a module with its initialization body.
  block:
    body

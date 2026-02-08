## Module module definition and lifecycle.
##
## Ported from Rust core/mods/module.rs

const
  RustPath* = "core/mods/module.rs"
  RustCrate* = "core"

type
  ModuleState* = enum
    msUnloaded
    msLoading
    msLoaded
    msUnloading
    msFailed

  Module* = ref object
    ## Represents a loadable server module.
    name*: string
    path*: string
    state*: ModuleState

proc newModule*(name, path: string): Module =
  Module(name: name, path: path, state: msUnloaded)

proc load*(m: Module) =
  ## Load a module. In Nim, modules are compiled in; this is a
  ## conceptual lifecycle marker.
  m.state = msLoaded

proc unload*(m: Module) =
  ## Unload a module.
  m.state = msUnloaded

proc isLoaded*(m: Module): bool = m.state == msLoaded
proc isFailed*(m: Module): bool = m.state == msFailed

## Module new — module constructor utilities.
##
## Ported from Rust core/mods/new.rs

import ./module

const
  RustPath* = "core/mods/new.rs"
  RustCrate* = "core"

proc newModuleFromPath*(path: string): Module =
  ## Create a new module from a filesystem path.
  let name = path.splitPath().tail.changeFileExt("")
  newModule(name, path)

import std/os

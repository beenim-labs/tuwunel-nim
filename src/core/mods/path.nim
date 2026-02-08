## Module path utilities — resolve module paths.
##
## Ported from Rust core/mods/path.rs

import std/os

const
  RustPath* = "core/mods/path.rs"
  RustCrate* = "core"

proc modulePath*(name: string; baseDir: string = ""): string =
  ## Resolve the expected path for a module by name.
  let dir = if baseDir.len > 0: baseDir else: getAppDir()
  dir / "modules" / name & ".so"

proc moduleExists*(name: string; baseDir: string = ""): bool =
  ## Check if a module file exists.
  fileExists(modulePath(name, baseDir))

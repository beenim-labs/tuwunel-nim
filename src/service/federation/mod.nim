const
  RustPath* = "service/federation/mod.rs"
  RustCrate* = "service"

import service/federation/[execute, format]

export execute, format

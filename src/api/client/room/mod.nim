const
  RustPath* = "api/client/room/mod.rs"
  RustCrate* = "api"

proc roomModuleNames*(): seq[string] =
  @[
    "aliases",
    "create",
    "event",
    "initial_sync",
    "summary",
    "timestamp",
    "upgrade",
  ]

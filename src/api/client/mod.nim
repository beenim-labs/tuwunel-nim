const
  RustPath* = "api/client/mod.rs"
  RustCrate* = "api"
  TokenLength* = 32
  SessionIdLength* = 32

proc clientModuleNames*(): seq[string] =
  @[
    "account", "account_data", "alias", "appservice", "backup", "capabilities",
    "context", "dehydrated_device", "device", "directory", "events", "filter",
    "keys", "media", "media_legacy", "membership", "message", "openid",
    "presence", "profile", "push", "read_marker", "redact", "register",
    "relations", "report", "room", "rtc", "search", "send", "session",
    "space", "state", "sync", "tag", "thirdparty", "threads", "to_device",
    "tuwunel", "typing", "unstable", "user_directory", "versions", "voip",
    "well_known",
  ]

## Generated config defaults — compile-time default values.
##
## Ported from generated Rust config defaults.

import std/json

const
  RustPath* = "core/config (generated defaults)"
  RustCrate* = "core"

proc defaultConfigValues*(): JsonNode =
  ## Return the default configuration as a JSON object.
  %*{
    "server_name": "your.server.name",
    "database_path": "./tuwunel_db",
    "port": 6167,
    "max_request_size": 20_000_000,
    "allow_registration": false,
    "allow_federation": true,
    "allow_local_presence": true,
    "allow_outgoing_presence": true,
    "allow_incoming_presence": true,
    "allow_invalid_tls_certificates": false,
    "default_room_version": "10",
    "listening": true,
    "log": "info",
    "rocksdb_max_log_files": 3,
    "rocksdb_log_level": "error",
    "sentry": false,
    "suppress_push_when_active": false,
    "ip_range_denylist": [],
    "url_preview_domain_contains_allowlist": [],
    "url_preview_domain_explicit_allowlist": [],
    "url_preview_url_contains_allowlist": [],
  }

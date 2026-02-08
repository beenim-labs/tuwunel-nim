## Generated config keys — known configuration key names.
##
## Ported from generated Rust config keys.

const
  RustPath* = "core/config (generated keys)"
  RustCrate* = "core"

const KNOWN_CONFIG_KEYS* = [
  "server_name", "database_path", "database_backend",
  "port", "address", "unix_socket_path",
  "max_request_size", "max_concurrent_requests",
  "allow_registration", "registration_token", "registration_token_file",
  "allow_federation", "allow_public_room_directory_over_federation",
  "allow_local_presence", "allow_outgoing_presence", "allow_incoming_presence",
  "allow_invalid_tls_certificates",
  "default_room_version",
  "listening", "log", "log_colors",
  "rocksdb_max_log_files", "rocksdb_log_level",
  "sentry", "sentry_endpoint",
  "emergency_password",
  "suppress_push_when_active",
  "ip_range_denylist",
  "url_preview_domain_contains_allowlist",
  "url_preview_domain_explicit_allowlist",
  "url_preview_url_contains_allowlist",
  "url_preview_bound_interface",
  "proxy",
  "yes_i_am_very_very_sure_i_want_an_open_registration_server_prone_to_abuse",
  "identity_provider", "sso_custom_providers_page",
]

const DEPRECATED_KEYS* = [
  "cache_capacity",
  "max_fetch_prev_events",
]

## Configuration validation — startup and reload checks.
##
## Ported from Rust core/config/check.rs — validates configuration
## integrity, warns on deprecated keys, checks for unsafe settings.

import std/[os, logging, strformat]

const
  RustPath* = "core/config/check.rs"
  RustCrate* = "core"

type
  ConfigCheckResult* = object
    ok*: bool
    errors*: seq[string]
    warnings*: seq[string]

proc newCheckResult*(): ConfigCheckResult =
  ConfigCheckResult(ok: true)

proc addError*(r: var ConfigCheckResult; msg: string) =
  r.ok = false
  r.errors.add msg

proc addWarning*(r: var ConfigCheckResult; msg: string) =
  r.warnings.add msg

proc checkConfigBasic*(
  serverName: string;
  allowRegistration: bool;
  registrationToken: string;
  allowInvalidTls: bool;
  maxRequestSize: int;
  rocksdbMaxLogFiles: int;
): ConfigCheckResult =
  ## Perform basic configuration validation checks.
  result = newCheckResult()

  when not defined(debug):
    if serverName == "your.server.name":
      result.addError("You must specify a valid server name for production usage.")

  if allowInvalidTls:
    result.addWarning("TLS CERTIFICATE VALIDATION IS DISABLED. HIGHLY INSECURE.")

  if rocksdbMaxLogFiles == 0:
    result.addError("rocksdb_max_log_files cannot be 0. Set at least 1.")

  if maxRequestSize < 10_000_000:
    result.addError("max_request_size is less than 10MB. Too low for federation.")

  if allowRegistration and registrationToken.len == 0:
    result.addError(
      "allow_registration is enabled without a registration token. " &
      "Set registration_token or set " &
      "yes_i_am_very_very_sure_i_want_an_open_registration_server_prone_to_abuse to true."
    )

proc checkReload*(oldServerName, newServerName: string): ConfigCheckResult =
  ## Validate config reload — server name cannot change.
  result = newCheckResult()
  if oldServerName != newServerName:
    result.addError(&"Cannot change server_name from '{oldServerName}'.")

proc isDualListening*(hasAddress, hasUnixSocket: bool): ConfigCheckResult =
  ## Check for conflicting address and unix_socket_path.
  result = newCheckResult()
  if hasAddress and hasUnixSocket:
    result.addError(
      "Both 'address' and 'unix_socket_path' defined. Specify only one."
    )

proc warnDeprecated*(keys: openArray[string]; deprecatedKeys: openArray[string]) =
  ## Warn about deprecated configuration keys.
  for key in keys:
    for dk in deprecatedKeys:
      if key == dk:
        warn(&"Config parameter \"{key}\" is deprecated, ignoring.")

proc warnUnknownKeys*(keys: openArray[string]; knownKeys: openArray[string]) =
  ## Warn about unknown configuration keys.
  for key in keys:
    if key == "config":
      continue
    var found = false
    for kk in knownKeys:
      if key == kk:
        found = true
        break
    if not found:
      warn(&"Config parameter \"{key}\" is unknown to tuwunel, ignoring.")

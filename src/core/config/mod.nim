## config — core module.
##
## Ported from Rust core/config/mod.rs

import std/[options, json, tables]

const
  RustPath* = "core/config/mod.rs"
  RustCrate* = "core"

# import ./check
# import ./manager
# import ./proxy

type
  Config* = ref object
    serverName*: string
    databasePath*: string
    newUserDisplaynameSuffix*: string
    tls*: string
    unixSocketPath*: string
    unixSocketPerms*: string
    databaseBackupPath*: string
    databaseBackupsToKeep*: string

type
  TlsConfig* = ref object
    certs*: string
    key*: string
    dualProtocol*: string

type
  WellKnownConfig* = ref object
    client*: string
    server*: string
    supportPage*: string
    supportRole*: string
    supportEmail*: string
    supportMxid*: string
    rtcTransports*: string

type
  BlurhashConfig* = ref object
    componentsX*: string
    componentsY*: string
    blurhashMaxRawSize*: string

type
  LdapConfig* = ref object
    enable*: string
    uri*: string
    baseDn*: string

proc id*() =
  ## Ported from `id`.
  discard

proc getClientSecret*() =
  ## Ported from `get_client_secret`.
  discard

proc from*() =
  ## Ported from `from`.
  discard

proc from*() =
  ## Ported from `from`.
  discard

proc getBindAddrs*() =
  ## Ported from `get_bind_addrs`.
  discard

proc getBindHosts*() =
  ## Ported from `get_bind_hosts`.
  discard

proc getBindPorts*() =
  ## Ported from `get_bind_ports`.
  discard

proc check*() =
  ## Ported from `check`.
  discard

proc trueFn*() =
  ## Ported from `true_fn`.
  discard

proc defaultServerName*() =
  ## Ported from `default_server_name`.
  discard

proc defaultDatabasePath*() =
  ## Ported from `default_database_path`.
  discard

proc defaultAddress*() =
  ## Ported from `default_address`.
  discard

proc defaultPort*() =
  ## Ported from `default_port`.
  discard

proc defaultUnixSocketPerms*() =
  ## Ported from `default_unix_socket_perms`.
  discard

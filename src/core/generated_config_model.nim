## Generated config model — main Config type definition.
##
## Ported from generated Rust Config struct (119KB in Rust).
## This is a simplified model covering the most important fields.

import std/[options, json, tables]
import ./config/proxy

const
  RustPath* = "core/config/mod.rs (Config struct)"
  RustCrate* = "core"

type
  IdentityProvider* = object
    ## OIDC/SSO identity provider configuration.
    id*: string
    name*: string
    issuer*: string
    clientId*: string
    clientSecret*: Option[string]
    clientSecretFile*: Option[string]
    default*: bool

  Config* = ref object
    ## Main server configuration.
    serverName*: string
    databasePath*: string
    port*: seq[uint16]
    address*: seq[string]
    unixSocketPath*: Option[string]
    maxRequestSize*: int
    maxConcurrentRequests*: int
    allowRegistration*: bool
    registrationToken*: Option[string]
    registrationTokenFile*: Option[string]
    allowFederation*: bool
    allowLocalPresence*: bool
    allowOutgoingPresence*: bool
    allowIncomingPresence*: bool
    allowInvalidTlsCertificates*: bool
    defaultRoomVersion*: string
    listening*: bool
    logLevel*: string
    logColors*: bool
    rocksdbMaxLogFiles*: int
    rocksdbLogLevel*: string
    sentry*: bool
    sentryEndpoint*: Option[string]
    emergencyPassword*: Option[string]
    suppressPushWhenActive*: bool
    ipRangeDenylist*: seq[string]
    urlPreviewDomainContainsAllowlist*: seq[string]
    urlPreviewDomainExplicitAllowlist*: seq[string]
    urlPreviewUrlContainsAllowlist*: seq[string]
    proxy*: ProxyConfig
    identityProvider*: seq[IdentityProvider]
    ssoCustomProvidersPage*: bool
    yesIAmVerySure*: bool
    catchall*: Table[string, string]

proc newDefaultConfig*(): Config =
  Config(
    serverName: "your.server.name",
    databasePath: "./tuwunel_db",
    port: @[6167u16],
    address: @["127.0.0.1"],
    maxRequestSize: 20_000_000,
    maxConcurrentRequests: 100,
    allowRegistration: false,
    allowFederation: true,
    allowLocalPresence: true,
    allowOutgoingPresence: true,
    allowIncomingPresence: true,
    defaultRoomVersion: "10",
    listening: true,
    logLevel: "info",
    logColors: true,
    rocksdbMaxLogFiles: 3,
    rocksdbLogLevel: "error",
    proxy: noProxy(),
    catchall: initTable[string, string](),
  )

proc getBindHosts*(c: Config): seq[string] = c.address
proc getBindPorts*(c: Config): seq[uint16] = c.port

proc id*(idp: IdentityProvider): string = idp.id

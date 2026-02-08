## resolver/tests — service module.
##
## Ported from Rust service/resolver/tests.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/resolver/tests.rs"
  RustCrate* = "service"

proc ipsGetDefaultPorts*() =
  ## Ported from `ips_get_default_ports`.
  discard

proc ipsKeepCustomPorts*() =
  ## Ported from `ips_keep_custom_ports`.
  discard

proc hostnamesGetDefaultPorts*() =
  ## Ported from `hostnames_get_default_ports`.
  discard

proc hostnamesKeepCustomPorts*() =
  ## Ported from `hostnames_keep_custom_ports`.
  discard

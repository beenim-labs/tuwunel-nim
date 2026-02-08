## resolver/fed — service module.
##
## Ported from Rust service/resolver/fed.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/resolver/fed.rs"
  RustCrate* = "service"

type
  FedDest* = enum
    literal
    socketaddr
    named
    hoststring
    portstring

proc getIpWithPort*(destStr: string): Option[FedDest] =
  ## Ported from `get_ip_with_port`.
  none(FedDest)

proc addPortToHostname*(dest: string): FedDest =
  ## Ported from `add_port_to_hostname`.
  discard

proc httpsString*(): Deststring =
  ## Ported from `https_string`.
  discard

proc uriString*(): Deststring =
  ## Ported from `uri_string`.
  discard

proc hostname*(): Hoststring =
  ## Ported from `hostname`.
  discard

proc port*(): Option[u16] =
  ## Ported from `port`.
  none(u16)

proc defaultPort*(): Portstring =
  ## Ported from `default_port`.
  discard

proc size*(): int =
  ## Ported from `size`.
  0

## client/mod — service module.
##
## Ported from Rust service/client/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/client/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    default*: ClientLazylock
    urlPreview*: ClientLazylock
    externMedia*: ClientLazylock
    wellKnown*: ClientLazylock
    federation*: ClientLazylock
    synapse*: ClientLazylock
    sender*: ClientLazylock
    appservice*: ClientLazylock
    pusher*: ClientLazylock
    oauth*: ClientLazylock

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc make*(services: OnceServices): reqwest::Client =
  ## Ported from `make`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc base*(config: Config): reqwest::ClientBuilder =
  ## Ported from `base`.
  discard

proc builderInterface*(builder: reqwest::ClientBuilder; config: Option[string]): reqwest::ClientBuilder =
  ## Ported from `builder_interface`.
  discard

proc builderInterface*(builder: reqwest::ClientBuilder; config: Option[string]): reqwest::ClientBuilder =
  ## Ported from `builder_interface`.
  discard

proc appserviceResolver*(services: OnceServices): dyn Resolve =
  ## Ported from `appservice_resolver`.
  discard

proc validCidrRange*(self: Service; ip: IPAddress): bool =
  ## Ported from `valid_cidr_range`.
  false

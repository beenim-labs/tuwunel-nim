## oauth/providers — service module.
##
## Ported from Rust service/oauth/providers.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/oauth/providers.rs"
  RustCrate* = "service"

type
  Providers* = ref object
    discard

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc get*(self: Providers; id: string): Provider =
  ## Ported from `get`.
  discard

proc getConfig*(self: Providers; id: string): Provider =
  ## Ported from `get_config`.
  discard

proc getCached*(self: Providers; id: string): Option[Provider] =
  ## Ported from `get_cached`.
  none(Provider)

proc configure*(self: Providers; provider: Provider): Provider =
  ## Ported from `configure`.
  discard

proc discover*(self: Providers; provider: Provider): JsonValue =
  ## Ported from `discover`.
  discard

proc discoveryUrl*(provider: Provider): Url =
  ## Ported from `discovery_url`.
  discard

proc checkIssuer*(response: JsonObject<string; provider: Provider): JsonObject<string> =
  ## Ported from `check_issuer`.
  discard

proc makeUrl*(provider: Provider; path: string): Url =
  ## Ported from `make_url`.
  discard

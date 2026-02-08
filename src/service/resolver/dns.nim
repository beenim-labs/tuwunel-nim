## resolver/dns — service module.
##
## Ported from Rust service/resolver/dns.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/resolver/dns.rs"
  RustCrate* = "service"

type
  Resolver* = ref object
    discard

proc build*(server: Server; cache: Cache) =
  ## Ported from `build`.
  discard

proc create*(server: Server; conf: ResolverConfig; opts: ResolverOpts): TokioResolver =
  ## Ported from `create`.
  discard

proc configure*(server: Server): (ResolverConfig =
  ## Ported from `configure`.
  discard

proc configureOpts*(server: Server; opts: ResolverOpts): ResolverOpts =
  ## Ported from `configure_opts`.
  discard

proc clearCache*(self: Resolver) =
  ## Ported from `clear_cache`.
  discard

proc resolve*(self: Resolver; name: Name): Resolving =
  ## Ported from `resolve`.
  discard

proc resolve*(self: Resolver; name: Name): Resolving =
  ## Ported from `resolve`.
  discard

proc resolve*(self: Resolver; name: Name): Resolving =
  ## Ported from `resolve`.
  discard

proc hookedResolve*(cache: Cache; server: Server; resolver: TokioResolver; name: Name): Addrs> =
  ## Ported from `hooked_resolve`.
  discard

proc resolveToReqwest*(server: Server; resolver: TokioResolver; name: Name): Resolving =
  ## Ported from `resolve_to_reqwest`.
  discard

proc cachedToReqwest*(cached: CachedOverride): Resolving =
  ## Ported from `cached_to_reqwest`.
  discard

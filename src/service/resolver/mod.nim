## resolver/mod — service module.
##
## Ported from Rust service/resolver/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/resolver/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    cache*: Cache
    resolver*: Resolver

# import ./actual
# import ./cache
# import ./fed

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc clearCache*(self: Service) =
  ## Ported from `clear_cache`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

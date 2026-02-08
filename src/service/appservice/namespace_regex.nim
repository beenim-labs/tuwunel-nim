## appservice/namespace_regex — service module.
##
## Ported from Rust service/appservice/namespace_regex.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/appservice/namespace_regex.rs"
  RustCrate* = "service"

type
  NamespaceRegex* = ref object
    exclusive*: Option[RegexSet]
    nonExclusive*: Option[RegexSet]

proc isMatch*(self: NamespaceRegex; heystack: string): bool =
  ## Ported from `is_match`.
  false

proc isExclusiveMatch*(self: NamespaceRegex; heystack: string): bool =
  ## Ported from `is_exclusive_match`.
  false

proc tryFrom*(value: seq[Namespace]) =
  ## Ported from `try_from`.
  discard

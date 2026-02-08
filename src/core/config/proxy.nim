## Proxy configuration — domain-based proxy routing.
##
## Ported from Rust core/config/proxy.rs

import std/strutils

const
  RustPath* = "core/config/proxy.rs"
  RustCrate* = "core"

type
  ProxyKind* = enum
    pkNone       ## No proxy
    pkGlobal     ## Global proxy for all requests
    pkByDomain   ## Domain-based proxy rules

  WildCardedDomain* = object
    ## A domain pattern that supports wildcard matching.
    case isWildcard*: bool
    of true:
      suffix*: string   ## e.g. ".onion" for "*.onion"
    of false:
      exact*: string    ## exact domain match

  PartialProxyConfig* = object
    ## A proxy rule with include/exclude domain lists.
    url*: string
    includes*: seq[WildCardedDomain]
    excludes*: seq[WildCardedDomain]

  ProxyConfig* = object
    ## Complete proxy configuration.
    case kind*: ProxyKind
    of pkNone:
      discard
    of pkGlobal:
      globalUrl*: string
    of pkByDomain:
      proxies*: seq[PartialProxyConfig]

proc parseWildcardDomain*(s: string): WildCardedDomain =
  ## Parse a domain pattern, supporting "*." prefix for wildcard.
  if s.startsWith("*."):
    WildCardedDomain(isWildcard: true, suffix: s[1..^1])
  elif s == "*":
    WildCardedDomain(isWildcard: true, suffix: "")
  else:
    WildCardedDomain(isWildcard: false, exact: s)

proc matches*(wc: WildCardedDomain; domain: string): bool =
  ## Check if a domain matches this wildcard pattern.
  case wc.isWildcard
  of true:
    if wc.suffix.len == 0: true  # "*" matches everything
    else: domain.endsWith(wc.suffix)
  of false:
    domain == wc.exact

proc moreSpecificThan*(a, b: WildCardedDomain): bool =
  ## Check if pattern `a` is more specific than pattern `b`.
  if not a.isWildcard and b.isWildcard:
    b.matches(a.exact)
  elif a.isWildcard and b.isWildcard:
    a.suffix != b.suffix and a.suffix.endsWith(b.suffix)
  else:
    false

proc forUrl*(proxy: PartialProxyConfig; domain: string): bool =
  ## Check if this proxy should be used for the given domain.
  var includedBecause: int = -1   # index into includes, or -1
  var excludedBecause: int = -1   # index into excludes, or -1

  if proxy.includes.len == 0:
    includedBecause = int.high  # treat empty include as "*"
  else:
    for i, wc in proxy.includes:
      if wc.matches(domain):
        if includedBecause < 0 or
           (includedBecause != int.high and
            wc.moreSpecificThan(proxy.includes[includedBecause])):
          includedBecause = i

  for i, wc in proxy.excludes:
    if wc.matches(domain):
      if excludedBecause < 0 or
         wc.moreSpecificThan(proxy.excludes[excludedBecause]):
        excludedBecause = i

  if includedBecause >= 0 and excludedBecause >= 0:
    # Both matched — include wins if more specific
    if includedBecause == int.high:
      false  # wildcard include vs specific exclude
    else:
      proxy.includes[includedBecause].moreSpecificThan(
        proxy.excludes[excludedBecause])
  elif includedBecause >= 0:
    true
  else:
    false

proc noProxy*(): ProxyConfig =
  ProxyConfig(kind: pkNone)

proc globalProxy*(url: string): ProxyConfig =
  ProxyConfig(kind: pkGlobal, globalUrl: url)

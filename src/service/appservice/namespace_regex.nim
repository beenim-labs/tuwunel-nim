const
  RustPath* = "service/appservice/namespace_regex.rs"
  RustCrate* = "service"

import std/re

type
  AppserviceNamespace* = object
    regex*: string
    exclusive*: bool

  NamespaceRegex* = object
    caseSensitive*: bool
    exclusive*: seq[string]
    nonExclusive*: seq[string]

proc namespace*(regex: string; exclusive = false): AppserviceNamespace =
  AppserviceNamespace(regex: regex, exclusive: exclusive)

proc initNamespaceRegex*(
  caseSensitive: bool;
  values: openArray[AppserviceNamespace];
): NamespaceRegex =
  result = NamespaceRegex(caseSensitive: caseSensitive, exclusive: @[], nonExclusive: @[])
  for value in values:
    if value.exclusive:
      result.exclusive.add(value.regex)
    else:
      result.nonExclusive.add(value.regex)

proc regexMatches(pattern, input: string; caseSensitive: bool): bool =
  try:
    let effective =
      if caseSensitive:
        pattern
      else:
        "(?i)" & pattern
    input.match(re(effective))
  except CatchableError:
    false

proc matchesAny(patterns: openArray[string]; input: string; caseSensitive: bool): bool =
  for pattern in patterns:
    if regexMatches(pattern, input, caseSensitive):
      return true
  false

proc isExclusiveMatch*(namespace: NamespaceRegex; input: string): bool =
  matchesAny(namespace.exclusive, input, namespace.caseSensitive)

proc isMatch*(namespace: NamespaceRegex; input: string): bool =
  namespace.isExclusiveMatch(input) or
    matchesAny(namespace.nonExclusive, input, namespace.caseSensitive)

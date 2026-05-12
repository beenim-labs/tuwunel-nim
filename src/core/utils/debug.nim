import std/options

const
  RustPath* = "core/utils/debug.rs"
  RustCrate* = "core"

proc quoted(value: string): string =
  result = "\""
  for ch in value:
    case ch
    of '\\':
      result.add("\\\\")
    of '"':
      result.add("\\\"")
    of '\n':
      result.add("\\n")
    of '\r':
      result.add("\\r")
    of '\t':
      result.add("\\t")
    else:
      result.add(ch)
  result.add('"')

proc sliceTruncatedDebug*[T](values: openArray[T]; maxLen: int): string =
  result = "["
  let limit = min(max(maxLen, 0), values.len)
  for idx in 0 ..< limit:
    if idx > 0:
      result.add(", ")
    when T is string:
      result.add(quoted(values[idx]))
    else:
      result.add($values[idx])
  if values.len > limit:
    if limit > 0:
      result.add(", ")
    result.add(quoted("..."))
  result.add("]")

proc strTruncatedDebug*(value: string; maxLen: int): string =
  if value.len <= maxLen:
    return quoted(value)

  let bounded = max(maxLen, 0)
  var cut = value.len
  for idx, _ in value:
    if idx >= bounded:
      cut = idx
      break
  quoted(value[0 ..< cut]) & "..."

proc redactedDebug*(hasValue: bool): string =
  if hasValue:
    "Some(<redacted>)"
  else:
    "None"

proc redactedDebug*[T](value: Option[T]): string =
  redactedDebug(value.isSome)

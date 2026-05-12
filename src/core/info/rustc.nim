import std/[algorithm, sequtils, strutils]

const
  RustPath* = "core/info/rustc.rs"
  RustCrate* = "core"

var capturedFlags: seq[(string, seq[string])] = @[]

proc captureFlags*(crateName: string; flags: openArray[string]) =
  capturedFlags.add((crateName, @flags))

proc appendFeatures(result: var seq[string]; flags: openArray[string]) =
  var nextIsCfg = false
  for flag in flags:
    let isCfg = flag == "--cfg"
    if nextIsCfg and flag.startsWith("feature="):
      result.add(flag.split("=", 1)[1].strip(chars = {'"'}))
    nextIsCfg = isCfg

proc features*(): seq[string] =
  result = @[]
  for item in capturedFlags:
    appendFeatures(result, item[1])
  result.sort()
  result = result.deduplicate(isSorted = true)

proc version*(): string =
  "nim " & NimVersion

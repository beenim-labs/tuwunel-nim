import std/[os, strutils]

const
  RustPath* = "core/info/version.rs"
  RustCrate* = "core"
  Branding* = "Tuwunel"
  Semantic* = "1.4.9"

proc name*(): string =
  Branding

proc semantic*(): string =
  getEnv("TUWUNEL_NIM_SEMANTIC", Semantic)

proc detailed*(): string =
  let commit = getEnv("TUWUNEL_GIT_COMMIT", "")
  let sem = semantic()
  if commit.len > 0 and "-" in sem:
    sem & " (" & commit & ")"
  else:
    sem

proc version*(): string =
  for key in ["TUWUNEL_VERSION_EXTRA", "CONDUWUIT_VERSION_EXTRA", "CONDUIT_VERSION_EXTRA"]:
    let extra = getEnv(key, "")
    if extra.len > 0:
      return detailed() & " (" & extra & ")"
  detailed()

proc userAgent*(): string =
  name() & "/" & semantic()

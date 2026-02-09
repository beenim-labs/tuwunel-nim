import std/[os, osproc, sets, strutils, strtabs]

type
  RustDelegateResolution* = object
    ok*: bool
    binaryPath*: string
    reason*: string

  RustDelegateResult* = object
    delegated*: bool
    exitCode*: int
    message*: string

proc boolEnv(name: string; defaultValue: bool): bool =
  let raw = getEnv(name)
  if raw.len == 0:
    return defaultValue

  case raw.toLowerAscii()
  of "1", "true", "yes", "on":
    true
  of "0", "false", "no", "off":
    false
  else:
    defaultValue

proc normalize(path: string): string =
  if path.len == 0:
    return ""
  try:
    return path.absolutePath()
  except OSError:
    return path

proc candidateRoots(cwd: string): seq[string] =
  result = @[]
  result.add(cwd / ".." / "tuwunel")
  result.add(cwd / "tuwunel")

proc candidatePaths*(cwd, envRoot, envBin, appPath: string): seq[string] =
  result = @[]
  if envBin.len > 0:
    result.add(envBin)

  if envRoot.len > 0:
    result.add(envRoot / "target" / "release" / "tuwunel")
    result.add(envRoot / "target" / "debug" / "tuwunel")

  let appDir = normalize(appPath).parentDir()
  if appDir.len > 0:
    result.add(appDir / "tuwunel-rust")
    result.add(appDir / "tuwunel")
    result.add(appDir / ".." / "tuwunel" / "target" / "release" / "tuwunel")
    result.add(appDir / ".." / "tuwunel" / "target" / "debug" / "tuwunel")

  for root in candidateRoots(cwd):
    result.add(root / "target" / "release" / "tuwunel")
    result.add(root / "target" / "debug" / "tuwunel")

  for exeName in ["tuwunel-rust", "tuwunel_rs", "tuwunel-rs"]:
    let exe = findExe(exeName)
    if exe.len > 0:
      result.add(exe)

proc resolveRustDelegateBinary*(
    cwd = getCurrentDir();
    appPath = getAppFilename()): RustDelegateResolution =
  if boolEnv("TUWUNEL_NIM_DISABLE_RUST_DELEGATE", false):
    return RustDelegateResolution(ok: false, reason: "rust delegation disabled by env")

  let envBin = getEnv("TUWUNEL_RUST_BIN")
  let envRoot = getEnv("TUWUNEL_RUST_ROOT")
  let selfPath = normalize(appPath)

  var seen = initHashSet[string]()
  for candidate in candidatePaths(cwd, envRoot, envBin, appPath):
    let resolved = normalize(candidate)
    if resolved.len == 0 or resolved in seen:
      continue
    seen.incl(resolved)

    if resolved == selfPath:
      continue
    if fileExists(resolved):
      return RustDelegateResolution(ok: true, binaryPath: resolved, reason: "delegate binary resolved")

  if envBin.len > 0:
    return RustDelegateResolution(
      ok: false,
      reason: "TUWUNEL_RUST_BIN set but file not found or not usable",
    )

  RustDelegateResolution(ok: false, reason: "no compatible rust tuwunel binary found")

proc runRustDelegate*(argv = commandLineParams()): RustDelegateResult =
  let resolved = resolveRustDelegateBinary()
  if not resolved.ok:
    return RustDelegateResult(delegated: false, exitCode: 0, message: resolved.reason)

  try:
    var childEnv = newStringTable(modeCaseSensitive)
    for key, value in envPairs():
      childEnv[key] = value
    for key in [
      "TUWUNEL_RUST_BIN",
      "TUWUNEL_RUST_ROOT",
      "TUWUNEL_NIM_REQUIRE_RUST_ENGINE",
      "TUWUNEL_NIM_DISABLE_RUST_DELEGATE",
    ]:
      if key in childEnv:
        childEnv.del(key)

    let child = startProcess(
      command = resolved.binaryPath,
      args = argv,
      env = childEnv,
      options = {poParentStreams},
    )
    let code = waitForExit(child)
    close(child)
    return RustDelegateResult(
      delegated: true,
      exitCode: code,
      message: "delegated to rust binary: " & resolved.binaryPath,
    )
  except OSError:
    RustDelegateResult(
      delegated: false,
      exitCode: 0,
      message: "failed to launch rust delegate: " & getCurrentExceptionMsg(),
    )

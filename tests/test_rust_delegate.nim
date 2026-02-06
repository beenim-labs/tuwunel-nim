import std/[os, strutils, unittest]
import main/rust_delegate

template withEnv(name, value: string, body: untyped) =
  block:
    let had = existsEnv(name)
    let old = getEnv(name)
    if value.len == 0:
      delEnv(name)
    else:
      putEnv(name, value)
    try:
      body
    finally:
      if had:
        putEnv(name, old)
      else:
        delEnv(name)

proc writeExecutable(path, content: string) =
  writeFile(path, content)
  when defined(posix):
    var perms = getFilePermissions(path)
    perms.incl(fpUserExec)
    perms.incl(fpGroupExec)
    perms.incl(fpOthersExec)
    setFilePermissions(path, perms)

suite "Rust delegate runtime":
  test "resolve uses TUWUNEL_RUST_BIN when valid":
    let dir = getTempDir() / "tuwunel_nim_delegate_env_bin"
    createDir(dir)
    let bin = dir / "tuwunel-rust"
    writeExecutable(bin, "#!/bin/sh\nexit 0\n")

    withEnv("TUWUNEL_NIM_DISABLE_RUST_DELEGATE", ""):
      withEnv("TUWUNEL_RUST_BIN", bin):
        let res = resolveRustDelegateBinary(cwd = getCurrentDir(), appPath = getAppFilename())
        check res.ok
        check res.binaryPath.absolutePath() == bin.absolutePath()

  test "resolve skips self binary":
    let here = getCurrentDir() / "build" / "selfbin"
    createDir(here.parentDir())
    writeExecutable(here, "#!/bin/sh\nexit 0\n")

    withEnv("TUWUNEL_NIM_DISABLE_RUST_DELEGATE", ""):
      withEnv("TUWUNEL_RUST_BIN", here):
        let tmp = getTempDir() / "tuwunel_nim_delegate_self_skip"
        createDir(tmp)
        let res = resolveRustDelegateBinary(cwd = tmp, appPath = here)
        if res.ok:
          check res.binaryPath.absolutePath() != here.absolutePath()
        else:
          check "not found" in res.reason or "no compatible" in res.reason

  test "run delegate executes discovered binary":
    let root = getTempDir() / "tuwunel_nim_delegate_root"
    let relDir = root / "target" / "release"
    createDir(relDir)
    let bin = relDir / "tuwunel"
    writeExecutable(bin, "#!/bin/sh\nexit 7\n")

    withEnv("TUWUNEL_NIM_DISABLE_RUST_DELEGATE", ""):
      withEnv("TUWUNEL_RUST_BIN", ""):
        withEnv("TUWUNEL_RUST_ROOT", root):
          let res = runRustDelegate(@[])
          check res.delegated
          check res.exitCode == 7

  test "disable env prevents delegation":
    withEnv("TUWUNEL_NIM_DISABLE_RUST_DELEGATE", "true"):
      let res = runRustDelegate(@[])
      check not res.delegated
      check "disabled" in res.message.toLowerAscii()

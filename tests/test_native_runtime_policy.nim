import std/[os, unittest]
import main/entrypoint

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

suite "Native runtime policy":
  test "entrypoint ignores Rust delegate binaries and stays native":
    let dir = getTempDir() / "tuwunel_nim_native_runtime_policy"
    createDir(dir)
    let bin = dir / "tuwunel-rust"
    writeExecutable(bin, "#!/bin/sh\nexit 7\n")

    withEnv("TUWUNEL_NIM_BOOTSTRAP_ONLY", "true"):
      withEnv("TUWUNEL_RUST_BIN", bin):
        withEnv("CONDUIT_CONFIG", ""):
          withEnv("CONDUWUIT_CONFIG", ""):
            withEnv("TUWUNEL_CONFIG", ""):
              let code = main()
              check code == 0

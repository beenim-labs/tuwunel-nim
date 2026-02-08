## System utilities — CPU parallelism, exe path, fd limits.
##
## Ported from Rust core/utils/sys.rs

import std/[os, cpuinfo, strutils]
when defined(posix):
  import std/posix

const
  RustPath* = "core/utils/sys.rs"
  RustCrate* = "core"

proc availableParallelism*(): int =
  ## Return the number of available CPU cores.
  max(1, countProcessors())

proc currentExe*(): string =
  ## Return the current executable path, stripping " (deleted)" suffix.
  let exe = getAppFilename()
  if exe.endsWith(" (deleted)"):
    exe[0 ..< exe.len - " (deleted)".len]
  else:
    exe

proc currentExeDeleted*(): bool =
  ## Check if the current executable has been deleted or replaced.
  try:
    getAppFilename().endsWith(" (deleted)")
  except:
    false

proc maximizeFdLimit*() =
  ## Maximize the file descriptor limit (Unix only).
  ## This is a no-op on non-Unix platforms.
  when defined(posix):
    var rlim = RLimit(rlim_cur: 0, rlim_max: 0)
    if getrlimit(RLIMIT_NOFILE, rlim) == 0:
      if rlim.rlim_cur < rlim.rlim_max:
        rlim.rlim_cur = rlim.rlim_max
        discard setrlimit(RLIMIT_NOFILE, rlim)

proc ueventFind*(uevent: string; key: string): string =
  ## Parse KEY=VALUE contents of a uevent file, find value for key.
  for line in uevent.splitLines():
    let parts = line.split('=', maxsplit = 1)
    if parts.len == 2 and parts[0] == key:
      return parts[1]
  ""

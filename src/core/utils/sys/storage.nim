## Storage utilities — disk space, filesystem info.
##
## Ported from Rust core/utils/sys/storage.rs

import std/[os, strformat]

const
  RustPath* = "core/utils/sys/storage.rs"
  RustCrate* = "core"

type
  StorageInfo* = object
    totalBytes*: uint64
    freeBytes*: uint64
    availableBytes*: uint64

proc getStorageInfo*(path: string): StorageInfo =
  ## Get storage info for the filesystem containing `path`.
  ## Returns zeros if info is not available.
  when defined(posix):
    import std/posix
    var stat: Statvfs
    if statvfs(path.cstring, stat) == 0:
      return StorageInfo(
        totalBytes: uint64(stat.f_blocks) * uint64(stat.f_frsize),
        freeBytes: uint64(stat.f_bfree) * uint64(stat.f_frsize),
        availableBytes: uint64(stat.f_bavail) * uint64(stat.f_frsize),
      )
  StorageInfo()

proc prettyStorageInfo*(info: StorageInfo): string =
  ## Format storage info as a human-readable string.
  let used = info.totalBytes - info.freeBytes
  &"used: {used}, free: {info.freeBytes}, total: {info.totalBytes}"

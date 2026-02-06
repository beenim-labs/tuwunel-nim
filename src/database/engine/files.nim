## File-system helpers for engine operations.

import std/[os, times]

proc ensureDbDir*(path: string) =
  if path.len == 0:
    return
  if dirExists(path):
    return
  createDir(path)

proc dbExists*(path: string): bool =
  path.len > 0 and dirExists(path)

proc listDbFiles*(path: string): seq[string] =
  result = @[]
  if not dirExists(path):
    return
  for entry in walkDir(path):
    result.add(entry.path)

proc dbFileCount*(path: string): int =
  listDbFiles(path).len

proc timestampTag*(): string =
  let nowTs = now().toTime().toUnix()
  $nowTs

proc buildBackupPath*(root, suffix: string): string =
  if suffix.len == 0:
    return root
  root / suffix

proc removeDbDirIfEmpty*(path: string): bool =
  if not dirExists(path):
    return false
  if dbFileCount(path) > 0:
    return false
  removeDir(path)
  true

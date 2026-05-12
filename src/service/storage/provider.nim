const
  RustPath* = "service/storage/provider.rs"
  RustCrate* = "service"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/[algorithm, os, strutils, times]

type
  StorageProviderKind* = enum
    spLocal
    spS3

  CopyMode* = enum
    cmOverwrite
    cmCreate

  StorageProviderConfig* = object
    kind*: StorageProviderKind
    name*: string
    basePath*: string
    createIfMissing*: bool
    deleteEmptyDirectories*: bool
    startupCheck*: bool
    multipartThreshold*: int
    multipartPartSize*: int

  ObjectMeta* = object
    location*: string
    size*: int64
    modifiedUnix*: int64

  PutResult* = object
    location*: string
    size*: int64

  Provider* = ref object
    name*: string
    config*: StorageProviderConfig
    basePath*: string

proc defaultMultipartValue(value: int): int =
  if value > 0: value else: high(int)

proc validateRelativeLocation(location: string): seq[string] =
  result = @[]
  let normalized = location.strip().replace('\\', '/')
  if normalized.len == 0:
    raise newException(ValueError, "Storage object path is empty.")
  for part in normalized.split('/'):
    if part.len == 0 or part == ".":
      continue
    if part == "..":
      raise newException(ValueError, "Storage object path must not escape provider base path.")
    result.add(part)
  if result.len == 0:
    raise newException(ValueError, "Storage object path is empty.")

proc toAbsPath*(provider: Provider; location: string): string =
  if provider == nil:
    raise newException(ValueError, "Storage provider is nil.")
  var path = provider.basePath
  for part in validateRelativeLocation(location):
    path = path / part
  path

proc stripBasePath(provider: Provider; path: string): string =
  let absBase = normalizedPath(absolutePath(provider.basePath))
  let absPath = normalizedPath(absolutePath(path))
  if absPath == absBase:
    return ""
  var prefix = absBase
  if prefix.len > 0 and prefix[^1] != DirSep:
    prefix.add(DirSep)
  if absPath.startsWith(prefix):
    return absPath[prefix.len .. ^1].replace(DirSep, '/')
  absPath.replace(DirSep, '/')

proc initLocalProvider*(
    name: string,
    basePath: string,
    createIfMissing = true,
    deleteEmptyDirectories = false,
    startupCheck = false
): Provider =
  let trimmedBase = basePath.strip()
  if trimmedBase.len == 0:
    raise newException(ValueError, "Local storage provider base path is required.")
  if createIfMissing:
    createDir(trimmedBase)
  elif not dirExists(trimmedBase):
    raise newException(IOError, "Local storage provider base path does not exist: " & trimmedBase)

  Provider(
    name: if name.strip().len > 0: name.strip() else: "media",
    basePath: trimmedBase,
    config: StorageProviderConfig(
      kind: spLocal,
      name: if name.strip().len > 0: name.strip() else: "media",
      basePath: trimmedBase,
      createIfMissing: createIfMissing,
      deleteEmptyDirectories: deleteEmptyDirectories,
      startupCheck: startupCheck,
      multipartThreshold: high(int),
      multipartPartSize: high(int)
    )
  )

proc initS3Provider*(
    name: string,
    bucket = "",
    endpoint = "",
    basePath = ""
): Provider =
  ## S3 config is represented so parity audits can distinguish it from local
  ## storage, but the Nim runtime has no native S3 object-store client yet.
  let label = if name.strip().len > 0: name.strip() else: "s3"
  raise newException(
    IOError,
    "S3 storage provider '" & label & "' is not implemented in the Nim runtime yet."
  )

proc putOne*(provider: Provider; location: string; body: string): PutResult =
  let path = provider.toAbsPath(location)
  let dir = parentDir(path)
  if dir.len > 0:
    createDir(dir)
  writeFile(path, body)
  PutResult(location: location, size: body.len.int64)

proc get*(provider: Provider; location: string): string =
  readFile(provider.toAbsPath(location))

proc load*(provider: Provider; location: string): string =
  provider.get(location)

proc head*(provider: Provider; location: string): ObjectMeta =
  let path = provider.toAbsPath(location)
  if not fileExists(path):
    raise newException(IOError, "Storage object not found: " & location)
  ObjectMeta(
    location: location,
    size: getFileSize(path),
    modifiedUnix: getLastModificationTime(path).toUnix()
  )

proc cleanupEmptyParents(provider: Provider; path: string) =
  if not provider.config.deleteEmptyDirectories:
    return
  var dir = parentDir(path)
  let base = normalizedPath(absolutePath(provider.basePath))
  while dir.len > 0 and normalizedPath(absolutePath(dir)).startsWith(base):
    if normalizedPath(absolutePath(dir)) == base:
      break
    var empty = true
    for _ in walkDir(dir):
      empty = false
      break
    if not empty:
      break
    try:
      removeDir(dir)
    except OSError:
      break
    dir = parentDir(dir)

proc deleteOne*(provider: Provider; location: string): bool =
  let path = provider.toAbsPath(location)
  if not fileExists(path):
    return false
  removeFile(path)
  provider.cleanupEmptyParents(path)
  true

proc copy*(provider: Provider; src, dst: string; mode = cmOverwrite) =
  let srcPath = provider.toAbsPath(src)
  let dstPath = provider.toAbsPath(dst)
  if mode == cmCreate and fileExists(dstPath):
    raise newException(IOError, "Storage destination already exists: " & dst)
  let dir = parentDir(dstPath)
  if dir.len > 0:
    createDir(dir)
  copyFile(srcPath, dstPath)

proc rename*(provider: Provider; src, dst: string; mode = cmOverwrite) =
  let srcPath = provider.toAbsPath(src)
  let dstPath = provider.toAbsPath(dst)
  if mode == cmCreate and fileExists(dstPath):
    raise newException(IOError, "Storage destination already exists: " & dst)
  let dir = parentDir(dstPath)
  if dir.len > 0:
    createDir(dir)
  moveFile(srcPath, dstPath)
  provider.cleanupEmptyParents(srcPath)

proc list*(provider: Provider; prefix = ""): seq[ObjectMeta] =
  result = @[]
  let root =
    if prefix.strip().len > 0:
      provider.toAbsPath(prefix)
    else:
      provider.basePath
  if not dirExists(root):
    return @[]
  for path in walkDirRec(root):
    if fileExists(path):
      result.add(ObjectMeta(
        location: provider.stripBasePath(path),
        size: getFileSize(path),
        modifiedUnix: getLastModificationTime(path).toUnix()
      ))
  result.sort(proc(a, b: ObjectMeta): int = cmp(a.location, b.location))

proc ping*(provider: Provider) =
  if provider == nil:
    raise newException(ValueError, "Storage provider is nil.")
  if not dirExists(provider.basePath):
    raise newException(IOError, "Storage provider base path is unavailable: " & provider.basePath)
  discard provider.list()

proc multipartThreshold*(provider: Provider): int =
  defaultMultipartValue(provider.config.multipartThreshold)

proc multipartPartSize*(provider: Provider): int =
  defaultMultipartValue(provider.config.multipartPartSize)

proc chunked*(payload: string; partSize: int): seq[string] =
  result = @[]
  if partSize <= 0:
    raise newException(ValueError, "Chunk part size must be positive.")
  var offset = 0
  while offset < payload.len:
    let nextOffset = min(offset + partSize, payload.len)
    result.add(payload[offset ..< nextOffset])
    offset = nextOffset

const
  RustPath* = "admin/query/storage.rs"
  RustCrate* = "admin"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/[algorithm, strutils]

import "service/storage/mod"

type
  StorageDeleteResult* = object
    location*: string
    deleted*: bool
    error*: string

proc `$`*(meta: ObjectMeta): string =
  "ObjectMeta(location: \"" & meta.location & "\", size: " & $meta.size &
    ", modifiedUnix: " & $meta.modifiedUnix & ")"

proc `$`*(put: PutResult): string =
  "PutResult(location: \"" & put.location & "\", size: " & $put.size & ")"

proc `$`*(config: StorageProviderConfig): string =
  let kind =
    case config.kind
    of spLocal: "local"
    of spS3: "s3"
  "StorageProviderConfig(kind: " & kind &
    ", name: \"" & config.name &
    "\", basePath: \"" & config.basePath &
    "\", createIfMissing: " & $config.createIfMissing &
    ", deleteEmptyDirectories: " & $config.deleteEmptyDirectories &
    ", startupCheck: " & $config.startupCheck &
    ", multipartThreshold: " & $config.multipartThreshold &
    ", multipartPartSize: " & $config.multipartPartSize & ")"

proc parseProviderLocation(src: string): (string, string) =
  let marker = src.find("//")
  if marker < 0:
    return ("", src)
  (src[0 ..< marker], src[marker + 2 .. ^1])

proc providerFor(service: StorageService; providerName: string; location = ""): (Provider, string) =
  if providerName.len > 0:
    return (service.provider(providerName), location)
  let parsed = parseProviderLocation(location)
  if parsed[0].len > 0:
    return (service.provider(parsed[0]), parsed[1])
  (service.provider(""), parsed[1])

proc queryStorageConfigs*(service: StorageService; prefix = ""): string =
  result = ""
  for item in service.configs(prefix):
    result.add("\n`" & item[0] & "`\n" & $item[1] & "\n")

proc queryStorageProviders*(service: StorageService): string =
  result = ""
  for item in service.providers():
    result.add("\n`" & item.name & "`\n" & $item.config & "\n")

proc queryStorageDebug*(service: StorageService; providerName: string): string =
  let item = service.provider(providerName)
  "Provider(name: \"" & item.name & "\", basePath: \"" & item.basePath &
    "\", config: " & $item.config & ")\n"

proc queryStorageShow*(service: StorageService; providerName, src: string): string =
  let resolved = service.providerFor(providerName, src)
  $resolved[0].head(resolved[1]) & "\n"

proc queryStorageList*(service: StorageService; providerName: string; prefix = ""): string =
  result = ""
  let item = service.provider(providerName)
  for meta in item.list(prefix):
    result.add($meta & "\n")

proc sortedLocations(provider: Provider): seq[string] =
  result = @[]
  for meta in provider.list():
    result.add(meta.location)
  result.sort()

proc intersectionSorted(a, b: seq[string]): seq[string] =
  result = @[]
  var bIndex = 0
  var aSorted = a
  var bSorted = b
  aSorted.sort()
  bSorted.sort()
  for item in aSorted:
    while bIndex < bSorted.len and bSorted[bIndex] < item:
      inc bIndex
    if bIndex < bSorted.len and bSorted[bIndex] == item:
      result.add(item)

proc differenceSorted(a, b: seq[string]): seq[string] =
  result = @[]
  var bIndex = 0
  var aSorted = a
  var bSorted = b
  aSorted.sort()
  bSorted.sort()
  for item in aSorted:
    while bIndex < bSorted.len and bSorted[bIndex] < item:
      inc bIndex
    if bIndex >= bSorted.len or bSorted[bIndex] != item:
      result.add(item)

proc queryStorageDuplicates*(service: StorageService; providerA, providerB: string): string =
  result = ""
  let duplicates = intersectionSorted(
    service.provider(providerA).sortedLocations(),
    service.provider(providerB).sortedLocations()
  )
  for item in duplicates:
    result.add(item & "\n")

proc queryStorageDifferences*(service: StorageService; providerA, providerB: string): string =
  result = ""
  let differences = differenceSorted(
    service.provider(providerA).sortedLocations(),
    service.provider(providerB).sortedLocations()
  )
  for item in differences:
    result.add(item & "\n")

proc queryStorageCopy*(
    service: StorageService;
    providerName: string;
    force: bool;
    src, dst: string
): string =
  let mode = if force: cmOverwrite else: cmCreate
  let item = service.provider(providerName)
  item.copy(src, dst, mode)
  $item.head(dst) & "\n"

proc queryStorageMove*(
    service: StorageService;
    providerName: string;
    force: bool;
    src, dst: string
): string =
  let mode = if force: cmOverwrite else: cmCreate
  let item = service.provider(providerName)
  item.rename(src, dst, mode)
  $item.head(dst) & "\n"

proc queryStorageDelete*(
    service: StorageService;
    providerName: string;
    sources: openArray[string];
    verbose = false
): string =
  result = ""
  let item = service.provider(providerName)
  for src in sources:
    try:
      if item.deleteOne(src):
        if verbose:
          result.add("deleted " & src & "\n")
      else:
        result.add("failed: Storage object not found: " & src & "\n")
    except CatchableError as err:
      result.add("failed: " & err.msg & "\n")

proc queryStorageSync*(service: StorageService; srcProvider, dstProvider: string): string =
  result = ""
  let src = service.provider(srcProvider)
  let dst = service.provider(dstProvider)
  for item in differenceSorted(src.sortedLocations(), dst.sortedLocations()):
    let payload = src.get(item)
    let put = dst.putOne(item, payload)
    result.add("Moved " & item & " from " & srcProvider & " to " & dstProvider &
      "; " & $put & "\n")

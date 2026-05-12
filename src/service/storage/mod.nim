const
  RustPath* = "service/storage/mod.rs"
  RustCrate* = "service"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/strutils

import provider

export provider

type
  StorageService* = ref object
    providers*: seq[Provider]

proc newStorageService*(defaultMediaBasePath: string): StorageService =
  StorageService(providers: @[initLocalProvider("media", defaultMediaBasePath)])

proc newStorageService*(providers: openArray[Provider]): StorageService =
  StorageService(providers: @providers)

proc addProvider*(service: StorageService; provider: Provider) =
  if service == nil:
    raise newException(ValueError, "Storage service is nil.")
  if provider == nil:
    raise newException(ValueError, "Storage provider is nil.")
  service.providers.add(provider)

proc providers*(service: StorageService): seq[Provider] =
  if service == nil:
    raise newException(ValueError, "Storage service is nil.")
  service.providers

proc configs*(service: StorageService; namePrefix = ""): seq[(string, StorageProviderConfig)] =
  if service == nil:
    raise newException(ValueError, "Storage service is nil.")
  result = @[]
  for item in service.providers:
    if namePrefix.len == 0 or item.name.startsWith(namePrefix):
      result.add((item.name, item.config))

proc config*(service: StorageService; name: string): StorageProviderConfig =
  for item in service.configs(name):
    if item[0] == name:
      return item[1]
  raise newException(KeyError, "No configuration for provider: " & name)

proc provider*(service: StorageService; name: string): Provider =
  if service == nil:
    raise newException(ValueError, "Storage service is nil.")
  for item in service.providers:
    if item.name == name:
      return item
  raise newException(KeyError, "No storage provider named: " & name)

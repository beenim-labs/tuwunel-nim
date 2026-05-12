import std/[os, sequtils, strutils, unittest]

import admin/query/storage as storage_query
import "service/storage/mod"

proc freshDir(name: string): string =
  result = getTempDir() / name
  if dirExists(result):
    removeDir(result)
  createDir(result)

suite "Storage admin query parity":
  test "configs, providers, debug, show and list expose local provider state":
    let root = freshDir("tuwunel_nim_storage_admin_query_a")
    let service = newStorageService(root)
    let media = service.provider("media")
    discard media.putOne("rooms/one.bin", "hello")

    check queryStorageConfigs(service).contains("`media`")
    check queryStorageConfigs(service).contains("StorageProviderConfig(kind: local")
    check queryStorageProviders(service).contains("`media`")
    check queryStorageDebug(service, "media").contains("Provider(name: \"media\"")
    check queryStorageShow(service, "media", "rooms/one.bin").contains("size: 5")
    check queryStorageShow(service, "", "media//rooms/one.bin").contains("rooms/one.bin")
    check queryStorageList(service, "media").contains("rooms/one.bin")

  test "duplicates, differences and sync compare two providers by object location":
    let rootA = freshDir("tuwunel_nim_storage_admin_query_dups_a")
    let rootB = freshDir("tuwunel_nim_storage_admin_query_dups_b")
    let providerA = initLocalProvider("src", rootA)
    let providerB = initLocalProvider("dst", rootB)
    let service = newStorageService([providerA, providerB])

    discard providerA.putOne("same.bin", "one")
    discard providerA.putOne("only-a.bin", "two")
    discard providerB.putOne("same.bin", "three")

    check queryStorageDuplicates(service, "src", "dst") == "same.bin\n"
    check queryStorageDifferences(service, "src", "dst") == "only-a.bin\n"

    let sync = queryStorageSync(service, "src", "dst")
    check sync.contains("Moved only-a.bin from src to dst")
    check providerB.get("only-a.bin") == "two"

  test "copy, move and delete follow Rust create-vs-overwrite behavior":
    let root = freshDir("tuwunel_nim_storage_admin_query_mutation")
    let service = newStorageService(root)
    let media = service.provider("media")

    discard media.putOne("a.bin", "payload")
    check queryStorageCopy(service, "media", false, "a.bin", "b.bin").contains("b.bin")
    expect IOError:
      discard queryStorageCopy(service, "media", false, "a.bin", "b.bin")
    check queryStorageCopy(service, "media", true, "a.bin", "b.bin").contains("b.bin")

    check queryStorageMove(service, "media", false, "b.bin", "c.bin").contains("c.bin")
    check media.list().mapIt(it.location) == @["a.bin", "c.bin"]

    check queryStorageDelete(service, "media", ["a.bin", "missing.bin"], verbose = true) ==
      "deleted a.bin\nfailed: Storage object not found: missing.bin\n"
    check media.list().mapIt(it.location) == @["c.bin"]

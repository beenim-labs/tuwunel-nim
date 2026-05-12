import std/[os, sequtils, unittest]

import service/storage/provider

suite "Storage provider parity":
  test "chunked follows Rust object-store chunk behavior":
    check chunked("abcdefghijklmnopqrstuvwxy", 10) == @["abcdefghij", "klmnopqrst", "uvwxy"]
    check chunked("abcdefghijklmnopqrstuvwxyz1234", 10) == @["abcdefghij", "klmnopqrst", "uvwxyz1234"]
    check chunked("abcde", 10) == @["abcde"]
    check chunked("", 10).len == 0
    check chunked("payload", high(int)) == @["payload"]

  test "local provider stores, lists, copies, renames and deletes objects":
    let root = getTempDir() / "tuwunel_nim_storage_provider"
    if dirExists(root):
      removeDir(root)
    let provider = initLocalProvider("media", root, deleteEmptyDirectories = true)

    let put = provider.putOne("rooms/one.bin", "hello")
    check put.location == "rooms/one.bin"
    check put.size == 5
    check provider.get("rooms/one.bin") == "hello"
    check provider.head("rooms/one.bin").size == 5

    provider.copy("rooms/one.bin", "rooms/two.bin", cmCreate)
    check provider.get("rooms/two.bin") == "hello"

    provider.rename("rooms/two.bin", "archive/two.bin")
    check provider.get("archive/two.bin") == "hello"
    check provider.list().mapIt(it.location) == @["archive/two.bin", "rooms/one.bin"]

    check provider.deleteOne("rooms/one.bin")
    check not provider.deleteOne("rooms/missing.bin")
    provider.ping()

  test "local provider rejects path traversal":
    let root = getTempDir() / "tuwunel_nim_storage_provider_escape"
    if dirExists(root):
      removeDir(root)
    let provider = initLocalProvider("media", root)
    expect ValueError:
      discard provider.putOne("../escape.bin", "nope")

  test "s3 provider is explicit unsupported native parity gap":
    expect IOError:
      discard initS3Provider("archive", bucket = "bucket")

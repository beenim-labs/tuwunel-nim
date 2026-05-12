import std/[options, unittest]
import database/[db, map, serialization, types]

proc keyStrings(keys: seq[seq[byte]]): seq[string] =
  result = @[]
  for key in keys:
    result.add(fromByteSeq(key))

proc entryStrings(entries: seq[DbKeyValue]): seq[string] =
  result = @[]
  for entry in entries:
    result.add(fromByteSeq(entry.key) & "=" & fromByteSeq(entry.value))

suite "Database map API":
  test "open map validates handle and column family":
    let d = openInMemory()
    expect DbError:
      discard openMap(d, "")

  test "put/get/contains/del/count and batch-get":
    let d = openInMemory()
    let m = openMap(d, "global")

    let key1 = toByteSeq("k1")
    let key2 = toByteSeq("k2")
    let val1 = toByteSeq("v1")

    check m.count() == 0
    m.put(key1, val1)
    check m.contains(key1)
    check not m.contains(key2)
    check m.count() == 1

    let got = m.get(key1)
    check got.isSome
    check fromByteSeq(got.get) == "v1"

    let batch = m.getBatch(@[key1, key2])
    check batch.len == 2
    check batch[0].isSome
    check fromByteSeq(batch[0].get) == "v1"
    check batch[1].isNone

    check m.del(key1)
    check not m.del(key1)
    check m.count() == 0

  test "insert/remove aliases map to put/del":
    let d = openInMemory()
    let m = openMap(d, "global")

    let key = toByteSeq("alias")
    m.insert(key, toByteSeq("ok"))
    check m.contains(key)
    check m.remove(key)
    check not m.contains(key)

  test "clear removes all entries in the map":
    let d = openInMemory()
    let m = openMap(d, "global")
    m.put(toByteSeq("a"), toByteSeq("1"))
    m.put(toByteSeq("b"), toByteSeq("2"))
    check m.count() == 2
    m.clear()
    check m.count() == 0
    check not m.contains(toByteSeq("a"))
    check not m.contains(toByteSeq("b"))

  test "keys and streams are byte-ordered with bounds and prefixes":
    let d = openInMemory()
    let m = openMap(d, "global")

    for entry in [
      ("b/2", "v4"),
      ("a/2", "v2"),
      ("c/1", "v5"),
      ("b/1", "v3"),
      ("a/1", "v1"),
    ]:
      m.put(toByteSeq(entry[0]), toByteSeq(entry[1]))

    check keyStrings(m.keys()) == @["a/1", "a/2", "b/1", "b/2", "c/1"]
    check keyStrings(m.keysFrom(toByteSeq("b/1"))) == @["b/1", "b/2", "c/1"]
    check keyStrings(m.keysPrefix(toByteSeq("b/"))) == @["b/1", "b/2"]

    check keyStrings(m.revKeys()) == @["c/1", "b/2", "b/1", "a/2", "a/1"]
    check keyStrings(m.revKeysFrom(toByteSeq("b/2"))) == @["b/2", "b/1", "a/2", "a/1"]
    check keyStrings(m.revKeysPrefix(toByteSeq("b/"))) == @["b/2", "b/1"]

    check entryStrings(m.stream()) == @["a/1=v1", "a/2=v2", "b/1=v3", "b/2=v4", "c/1=v5"]
    check entryStrings(m.streamFrom(toByteSeq("b/1"))) == @["b/1=v3", "b/2=v4", "c/1=v5"]
    check entryStrings(m.streamPrefix(toByteSeq("a/"))) == @["a/1=v1", "a/2=v2"]
    check entryStrings(m.revStream()) == @["c/1=v5", "b/2=v4", "b/1=v3", "a/2=v2", "a/1=v1"]
    check entryStrings(m.revStreamFrom(toByteSeq("b/2"))) == @["b/2=v4", "b/1=v3", "a/2=v2", "a/1=v1"]
    check entryStrings(m.revStreamPrefix(toByteSeq("b/"))) == @["b/2=v4", "b/1=v3"]

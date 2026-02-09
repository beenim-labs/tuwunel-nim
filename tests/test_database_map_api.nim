import std/[options, unittest]
import database/[db, map, serialization, types]

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

  test "clear reports not implemented":
    let d = openInMemory()
    let m = openMap(d, "global")
    expect DbError:
      m.clear()

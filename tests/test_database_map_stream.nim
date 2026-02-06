import std/unittest
import database/[db, map, serialization]

suite "Database map stream and query API":
  test "forward/reverse key and stream projections":
    let d = openInMemory()
    let m = openMap(d, "global")

    m.put(toByteSeq("a:1"), toByteSeq("v1"))
    m.put(toByteSeq("a:2"), toByteSeq("v2"))
    m.put(toByteSeq("b:1"), toByteSeq("v3"))

    let keysAll = m.keys()
    check keysAll.len == 3

    let keysPref = m.keysPrefix(toByteSeq("a:"))
    check keysPref.len == 2

    let rev = m.revKeys()
    check rev.len == 3
    check rev[0] == toByteSeq("b:1")

    let streamPref = m.streamPrefix(toByteSeq("a:"))
    check streamPref.len == 2
    check streamPref[0].value == toByteSeq("v1")

  test "query and batch query behavior":
    let d = openInMemory()
    let m = openMap(d, "global")

    m.insert(toByteSeq("k1"), toByteSeq("v1"))
    m.insert(toByteSeq("k2"), toByteSeq("v2"))

    let hit = m.qry(toByteSeq("k1"))
    check hit.exists
    check hit.value.isSome
    check hit.value.get == toByteSeq("v1")

    let missing = m.qry(toByteSeq("k3"))
    check not missing.exists
    check missing.value.isNone

    let batch = m.qryBatch(@[toByteSeq("k1"), toByteSeq("k3")])
    check batch.len == 2
    check batch[0].exists
    check not batch[1].exists

  test "watch and compact reports":
    let d = openInMemory()
    let m = openMap(d, "global")

    let w1 = m.watchPut(toByteSeq("key"), toByteSeq("value"))
    check w1.existsAfter
    check w1.changed

    let w2 = m.watchDel(toByteSeq("key"))
    check w2.existedBefore
    check not w2.existsAfter

    m.put(toByteSeq("x1"), toByteSeq("1"))
    m.put(toByteSeq("x2"), toByteSeq("2"))
    let report = m.compact()
    check report.before >= report.after

import std/[unittest, options]
import database/[db, serialization]
import database/types

suite "Database runtime (in-memory backend)":
  test "put/get/delete in known column family":
    let d = openInMemory()
    let cf = "global"
    let k = serializeStringAndU64("server_name", 1'u64)
    let v = toByteSeq("example.com")

    check not d.contains(cf, k)

    d.put(cf, k, v)
    check d.contains(cf, k)
    check d.count(cf) == 1

    let got = d.get(cf, k)
    check got.isSome
    check fromByteSeq(got.get) == "example.com"

    check d.del(cf, k)
    check not d.contains(cf, k)
    check not d.del(cf, k)

  test "unknown column family throws":
    let d = openInMemory()
    expect DbError:
      d.put("missing_cf", @[byte(1)], @[byte(2)])

  test "schema assertion helper":
    let good = @["global"]
    expect DbError:
      assertSchemaCompatible(good)

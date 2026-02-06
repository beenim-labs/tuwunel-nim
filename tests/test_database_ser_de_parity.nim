import std/[options, unittest]
import database/[de, keyval, ser, serialization, types]

suite "Database serializer/deserializer parity":
  test "top-level string serialization is rejected":
    expect DbError:
      discard serializeString("plain")

  test "tuple and option-first framing":
    let room = toByteSeq("!room:example.com")
    let user = toByteSeq("@user:example.com")

    let encodedNone = serializeTupleOptionFirst(none(seq[byte]), user)
    check encodedNone.len > 0
    check encodedNone[0] == RecordSeparator

    let decodedNone = deserializeTupleOptionFirst(encodedNone)
    check decodedNone.a.isNone
    check fromByteSeq(decodedNone.b) == "@user:example.com"

    let encodedSome = serializeTupleOptionFirst(some(room), user)
    let decodedSome = deserializeTupleOptionFirst(encodedSome)
    check decodedSome.a.isSome
    check fromByteSeq(decodedSome.a.get) == "!room:example.com"
    check fromByteSeq(decodedSome.b) == "@user:example.com"

  test "tuple defaults and option-second behavior":
    let raw = toByteSeq("@user:example.com")
    let decodedDefault = deserializeTuple2DefaultSecond(raw)
    check fromByteSeq(decodedDefault.a) == "@user:example.com"
    check decodedDefault.b.len == 0

    let decodedOpt = deserializeTuple2OptionalSecond(raw)
    check decodedOpt.b.isNone

  test "u64 array roundtrip":
    let values = @[5'u64, 42'u64, 999'u64]
    let encoded = serializeU64Array(values)
    let decoded = deserializeU64Array(encoded)
    check decoded == values

  test "key/value helpers for string and u64":
    let key = serializeStringKey(["user", "123"])
    let decoded = deserializeTuple2StringKey(key)
    check decoded.a == "user"
    check decoded.b == "123"

    let v = serializeU64Value(987'u64)
    check deserializeU64Value(v) == 987'u64


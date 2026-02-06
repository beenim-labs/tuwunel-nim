import std/unittest
import database/serialization

suite "Database serialization helpers":
  test "u64 big-endian roundtrip":
    let v = 0x0102030405060708'u64
    let b = encodeU64BE(v)
    check b.len == 8
    check b[0] == 0x01'u8
    check b[7] == 0x08'u8
    check decodeU64BE(b) == v

  test "i64 big-endian roundtrip":
    let v = -123456789'i64
    let b = encodeI64BE(v)
    check b.len == 8
    check decodeI64BE(b) == v

  test "record framing roundtrip":
    let a = toByteSeq("room")
    let c = toByteSeq("event")
    let b = encodeU32BE(42'u32)
    let payload = serializeTuple3(a, b, c)

    check hasSeparator(payload)
    check countSeparators(payload) == 2

    let items = splitRecords(payload)
    check items.len == 3
    check fromByteSeq(items[0]) == "room"
    check decodeU32BE(items[1]) == 42'u32
    check fromByteSeq(items[2]) == "event"

  test "string and u64 helper":
    let payload = serializeStringAndU64("server", 99'u64)
    let items = splitRecords(payload)
    check items.len == 2
    check fromByteSeq(items[0]) == "server"
    check decodeU64BE(items[1]) == 99'u64
